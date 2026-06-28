<?php
/**
 * verify.php — Verificatore pubblico di firme PKCS#7/CMS (.p7m) in PHP puro.
 *
 * COMPATIBILE PHP 5.4 -> 8.3. Nessun type hint scalare, nessun return type,
 * nessuna proprieta tipizzata, nessun generatore (yield), nessun hint \GMP.
 *
 * Dipendenze: ext-gmp (modexp RSA) ed ext-hash (SHA-256), standard ovunque.
 * NON usa il binario openssl ne phpseclib.
 *
 * Uso:
 *   GET /verify.php?url=https://www.francocorbelli.it/catpaq/latest/win64/version.txt.p7m
 *   GET /verify.php?url=...&format=json
 *
 * Supporta: RSA-PKCS1v15 + SHA-256 (certificati qualificati ArubaPEC/InfoCert/Aruba).
 * Verifica crittografica (firma <-> contenuto, certificato ben formato). NON valida
 * la catena eIDAS / Trusted List AgID ne la revoca OCSP/CRL.
 *
 * Licenza: MIT — Franco Corbelli, https://github.com/zpaqfranz/catpaq
 */

// Guard: serve almeno un backend per il modexp RSA. Il backend "puro" non ha
// dipendenze, quindi questo scatta solo in ambienti PHP estremamente atipici.
if (!function_exists('gmp_powm') && !function_exists('bcpowmod') && !function_exists('bcmul')) {
    // Il modexp puro richiede comunque le funzioni base di stringa/array, sempre presenti.
    // Se anche quelle mancassero saremmo gia in errore prima di qui; il check resta
    // come segnale esplicito.
    $al = isset($_SERVER['HTTP_ACCEPT_LANGUAGE']) ? $_SERVER['HTTP_ACCEPT_LANGUAGE'] : '';
    $isIt = (stripos($al, 'it') === 0);
    header('HTTP/1.1 500 Internal Server Error');
    header('Content-Type: text/plain; charset=utf-8');
    if ($isIt) {
        echo "Errore: nessun backend per l'aritmetica a precisione arbitraria disponibile.\n";
        echo "Il servizio funziona con l'estensione 'gmp', oppure 'bcmath', oppure in PHP puro.\n";
    } else {
        echo "Error: no arbitrary-precision arithmetic backend available.\n";
        echo "This service works with the 'gmp' or 'bcmath' extension, or in pure PHP.\n";
    }
    exit;
}

// ============================================================
//  CONFIGURAZIONE
// ============================================================

// --- Modalita del servizio ------------------------------------------------
// Per personalizzare il servizio basta cambiare queste due costanti insieme.
//
//   OWNER_CF non vuoto  -> "modalita proprietario": se il file e firmato dal
//                          titolare di questo CF, compare un banner grande
//                          dedicato (OWNER_LABEL). Tutte le altre firme valide
//                          mostrano comunque il banner verde standard.
//   OWNER_CF = ''        -> "modalita universale": nessun firmatario speciale,
//                          ogni firma valida e trattata allo stesso modo.
//                          In questo caso OWNER_LABEL e ignorato.
//
define('OWNER_CF',    'CRBFNC72T25H294X');   // CF proprietario senza prefisso TINIT-, oppure '' per universale
define('OWNER_LABEL', 'Franco Corbelli');    // mostrato solo in modalita proprietario
// --------------------------------------------------------------------------
define('MAX_BYTES',     10 * 1024 * 1024);     // 10 MB
define('MAX_REDIRECTS', 3);
define('FETCH_TIMEOUT', 8);                    // secondi
define('USER_AGENT_STR','p7m-verify/1.0 (+https://github.com/zpaqfranz/catpaq)');

// OID
define('OID_SIGNED_DATA',    '1.2.840.113549.1.7.2');
define('OID_DATA',           '1.2.840.113549.1.7.1');
define('OID_MESSAGE_DIGEST', '1.2.840.113549.1.9.4');
define('OID_SIGNING_TIME',   '1.2.840.113549.1.9.5');
define('OID_RSA_ENC',        '1.2.840.113549.1.1.1');

// Registro algoritmi di digest supportati.
// Chiave = OID del digestAlgorithm; valori = nome per hash() e prefisso DigestInfo
// (RFC 8017) usato nella verifica PKCS#1 v1.5.
function digest_registry() {
    static $reg = null;
    if ($reg === null) {
        $reg = array(
            // SHA-256
            '2.16.840.1.101.3.4.2.1' => array(
                'name'   => 'sha256',
                'label'  => 'SHA-256',
                'prefix' => "\x30\x31\x30\x0d\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x01\x05\x00\x04\x20",
                'weak'   => false,
            ),
            // SHA-384
            '2.16.840.1.101.3.4.2.2' => array(
                'name'   => 'sha384',
                'label'  => 'SHA-384',
                'prefix' => "\x30\x41\x30\x0d\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x02\x05\x00\x04\x30",
                'weak'   => false,
            ),
            // SHA-512
            '2.16.840.1.101.3.4.2.3' => array(
                'name'   => 'sha512',
                'label'  => 'SHA-512',
                'prefix' => "\x30\x51\x30\x0d\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x03\x05\x00\x04\x40",
                'weak'   => false,
            ),
            // SHA-224
            '2.16.840.1.101.3.4.2.4' => array(
                'name'   => 'sha224',
                'label'  => 'SHA-224',
                'prefix' => "\x30\x2d\x30\x0d\x06\x09\x60\x86\x48\x01\x65\x03\x04\x02\x04\x05\x00\x04\x1c",
                'weak'   => false,
            ),
            // SHA-1 (riconosciuto ma deprecato)
            '1.3.14.3.2.26' => array(
                'name'   => 'sha1',
                'label'  => 'SHA-1',
                'prefix' => "\x30\x21\x30\x09\x06\x05\x2b\x0e\x03\x02\x1a\x05\x00\x04\x14",
                'weak'   => true,
            ),
        );
    }
    return $reg;
}

/** Restituisce la entry del registro per un OID digest, o null se non supportato. */
function digest_lookup($oid) {
    $reg = digest_registry();
    return isset($reg[$oid]) ? $reg[$oid] : null;
}

function dn_oid_map() {
    return array(
        '2.5.4.3'              => 'CN',
        '2.5.4.4'              => 'surname',
        '2.5.4.5'              => 'serialNumber',
        '2.5.4.6'              => 'C',
        '2.5.4.7'              => 'L',
        '2.5.4.8'              => 'ST',
        '2.5.4.10'             => 'O',
        '2.5.4.11'             => 'OU',
        '2.5.4.42'             => 'givenName',
        '2.5.4.46'             => 'dnQualifier',
        '2.5.4.97'             => 'organizationIdentifier',
        '1.2.840.113549.1.9.1' => 'emailAddress',
    );
}

function oid_name($oid) {
    static $map = array(
        '1.2.840.113549.1.1.11'  => 'sha256WithRSAEncryption',
        '1.2.840.113549.1.1.1'   => 'rsaEncryption',
        '2.16.840.1.101.3.4.2.1' => 'sha256',
        '1.2.840.113549.1.7.1'   => 'pkcs7-data',
        '1.2.840.113549.1.7.2'   => 'pkcs7-signedData',
    );
    return isset($map[$oid]) ? $map[$oid] : $oid;
}

// ============================================================
//  LINGUA — italiano se il browser e italiano, altrimenti inglese
// ============================================================

/** Rileva la lingua dall'header Accept-Language. Ritorna 'it' o 'en'. */
function detect_lang() {
    $al = isset($_SERVER['HTTP_ACCEPT_LANGUAGE']) ? $_SERVER['HTTP_ACCEPT_LANGUAGE'] : '';
    // primo tag di lingua, es. "it-IT,it;q=0.9,en;q=0.8" -> "it"
    if (preg_match('/^\s*([a-zA-Z]{2})/', $al, $m)) {
        if (strtolower($m[1]) === 'it') {
            return 'it';
        }
    }
    return 'en';
}

/** Tabella stringhe UI. $key -> array('it'=>..., 'en'=>...). */
function t($key) {
    static $S = array(
        'title'          => array('it' => 'Verifica P7M',                 'en' => 'P7M Verification'),
        'signer'         => array('it' => 'Firmatario',                   'en' => 'Signer'),
        'organization'   => array('it' => 'Organizzazione',               'en' => 'Organization'),
        'name'           => array('it' => 'Nome',                         'en' => 'Name'),
        'surname'        => array('it' => 'Cognome',                      'en' => 'Surname'),
        'givenname'      => array('it' => 'Nome proprio',                 'en' => 'Given name'),
        'fiscalcode'     => array('it' => 'Codice fiscale',              'en' => 'Italian fiscal code'),
        'serialnumber'   => array('it' => 'serialNumber',                'en' => 'serialNumber'),
        'certificate'    => array('it' => 'Certificato',                 'en' => 'Certificate'),
        'issuedby'       => array('it' => 'Emesso da',                   'en' => 'Issued by'),
        'validfrom'      => array('it' => 'Valido dal',                  'en' => 'Valid from'),
        'validto'        => array('it' => 'Valido al',                   'en' => 'Valid to'),
        'certsha'        => array('it' => 'SHA-256 cert',               'en' => 'Certificate SHA-256'),
        'algorithm'      => array('it' => 'Algoritmo',                   'en' => 'Algorithm'),
        'signingtime'    => array('it' => 'Signing time',               'en' => 'Signing time'),
        'signedcontent'  => array('it' => 'Contenuto firmato',          'en' => 'Signed content'),
        'size'           => array('it' => 'Dimensione',                 'en' => 'Size'),
        'sha256'         => array('it' => 'SHA-256',                     'en' => 'SHA-256'),
        'payloadprev'    => array('it' => 'Anteprima payload',          'en' => 'Payload preview'),
        'truncated'      => array('it' => '(troncato ai primi 2048 byte)', 'en' => '(truncated to first 2048 bytes)'),
        'origin'         => array('it' => 'Origine',                     'en' => 'Origin'),
        'downloadedfrom' => array('it' => 'Scaricato da:',              'en' => 'Downloaded from:'),
        'downloadedsha'  => array('it' => 'SHA-256 del file scaricato:','en' => 'SHA-256 of the downloaded file:'),
        'redirectchain'  => array('it' => 'Catena redirect:',          'en' => 'Redirect chain:'),
        'verifylog'      => array('it' => 'Log di verifica',           'en' => 'Verification log'),
        'banner_owner'   => array('it' => 'FIRMATO DA',                'en' => 'SIGNED BY'),
        'banner_ownsub'  => array('it' => 'Codice fiscale %s &mdash; firma crittografica valida',
                                  'en' => 'Fiscal code %s &mdash; cryptographic signature valid'),
        'banner_valid'   => array('it' => 'Firma VALIDA',              'en' => 'Signature VALID'),
        'banner_signedby'=> array('it' => 'Firmato da %s',             'en' => 'Signed by %s'),
        'banner_invalid' => array('it' => 'Firma NON valida',          'en' => 'Signature NOT valid'),
        'banner_failed'  => array('it' => 'verifica fallita',          'en' => 'verification failed'),
        'unknown_signer' => array('it' => 'firmatario sconosciuto',    'en' => 'unknown signer'),
        'download_failed'=> array('it' => 'Download fallito: ',        'en' => 'Download failed: '),
        'footer_note'    => array(
            'it' => 'Verifica crittografica indipendente (firma &harr; contenuto, certificato ben formato). Non costituisce validazione legale eIDAS: non vengono controllate la catena di certificazione, la presenza nella Trusted List AgID, ne lo stato di revoca (OCSP/CRL).',
            'en' => 'Independent cryptographic verification (signature &harr; content, well-formed certificate). This is not a legal eIDAS validation: the certification chain, presence in the AgID Trusted List, and revocation status (OCSP/CRL) are not checked.'),
        'form_intro'     => array(
            'it' => 'Incolla l&#39;URL di un file <code>.p7m</code> firmato. Il server lo scarica e ne verifica la firma.',
            'en' => 'Paste the URL of a signed <code>.p7m</code> file. The server downloads it and verifies the signature.'),
        'form_button'    => array('it' => 'Verifica',                  'en' => 'Verify'),
        'form_json'      => array('it' => 'Aggiungi <code>&amp;format=json</code> per l&#39;output JSON.',
                                  'en' => 'Add <code>&amp;format=json</code> for JSON output.'),
        'form_heading'   => array('it' => 'Verifica firma .p7m',       'en' => 'Verify .p7m signature'),
    );
    $lang = detect_lang();
    if (!isset($S[$key])) {
        return $key;
    }
    return isset($S[$key][$lang]) ? $S[$key][$lang] : $S[$key]['en'];
}

// ============================================================
//  ASN.1 DER — reader minimale (array-based, no classi tipizzate)
// ============================================================

/**
 * Legge un nodo DER a offset $pos nella stringa $d.
 * Restituisce array: tag, start (contenuto), len, hstart (tag), hlen, end.
 * Lancia Exception in caso di errore.
 */
function der_read($d, $n, $pos) {
    if ($pos >= $n) {
        throw new Exception("read: pos past end ($pos)");
    }
    $hstart = $pos;
    $tag = ord($d[$pos]);
    $pos++;

    if ($pos >= $n) {
        throw new Exception('read: missing length');
    }
    $first = ord($d[$pos]);
    $pos++;

    if (($first & 0x80) === 0) {
        $len = $first;
    } else {
        $nbytes = $first & 0x7F;
        if ($nbytes === 0 || $nbytes > 4) {
            throw new Exception("read: unsupported length form ($nbytes bytes)");
        }
        $len = 0;
        for ($i = 0; $i < $nbytes; $i++) {
            if ($pos >= $n) {
                throw new Exception('read: truncated length');
            }
            $len = ($len << 8) | ord($d[$pos]);
            $pos++;
        }
    }

    if ($pos + $len > $n) {
        throw new Exception("read: content past end (start=$pos len=$len)");
    }

    return array(
        'tag'    => $tag,
        'start'  => $pos,
        'len'    => $len,
        'hstart' => $hstart,
        'hlen'   => $pos - $hstart,
        'end'    => $pos + $len,
    );
}

function der_expect($d, $n, $pos, $tag) {
    $node = der_read($d, $n, $pos);
    if ($node['tag'] !== $tag) {
        throw new Exception(sprintf('expected tag 0x%02X, found 0x%02X at offset %d', $tag, $node['tag'], $pos));
    }
    return $node;
}

/** Restituisce un array di nodi figli del nodo $parent. */
function der_children($d, $n, $parent) {
    $out = array();
    $pos = $parent['start'];
    $end = $parent['end'];
    while ($pos < $end) {
        $child = der_read($d, $n, $pos);
        $out[] = $child;
        $pos = $child['end'];
    }
    return $out;
}

function der_str($d, $node) {
    return substr($d, $node['start'], $node['len']);
}

/** OBJECT IDENTIFIER -> stringa dotted-decimal. */
function der_oid($d, $node) {
    if ($node['tag'] !== 0x06) {
        throw new Exception('oid: node is not OBJECT IDENTIFIER');
    }
    $bytes = substr($d, $node['start'], $node['len']);
    $len = strlen($bytes);
    if ($len === 0) {
        return '';
    }
    $first = ord($bytes[0]);
    $out = array(intval($first / 40), $first % 40);
    $val = 0;
    for ($i = 1; $i < $len; $i++) {
        $b = ord($bytes[$i]);
        $val = ($val << 7) | ($b & 0x7F);
        if (($b & 0x80) === 0) {
            $out[] = $val;
            $val = 0;
        }
    }
    return implode('.', $out);
}

// ============================================================
//  BIG INTEGER — modexp con backend multipli
//  Prova GMP (veloce), poi BCMath, infine PHP puro (nessuna dipendenza).
//  Tutte le funzioni lavorano su stringhe binarie big-endian.
// ============================================================

/** Quale backend bigint usare. Calcolato una volta. */
function bn_backend() {
    static $b = null;
    if ($b === null) {
        if (function_exists('gmp_powm')) {
            $b = 'gmp';
        } elseif (function_exists('bcpowmod')) {
            $b = 'bcmath';
        } else {
            $b = 'pure';
        }
    }
    return $b;
}

function ltrim_sign($intBytes) {
    while (strlen($intBytes) > 1 && $intBytes[0] === "\x00") {
        $intBytes = substr($intBytes, 1);
    }
    return $intBytes;
}

/** Interi PICCOLI big-endian (es. version) -> int PHP. Non per valori enormi. */
function be_to_int($bytes) {
    $bytes = ltrim($bytes, "\x00");
    $v = 0;
    $len = strlen($bytes);
    // limita a 4 byte per sicurezza su 32-bit
    if ($len > 4) { $bytes = substr($bytes, $len - 4); $len = 4; }
    for ($i = 0; $i < $len; $i++) {
        $v = ($v << 8) | ord($bytes[$i]);
    }
    return $v;
}

/**
 * modexp: ($base ^ $exp) mod $mod, tutti big-endian binari.
 * Restituisce big-endian zero-padded a $size byte. $base < $mod NON garantito.
 */
function bn_modexp_be($base, $exp, $mod, $size) {
    switch (bn_backend()) {
        case 'gmp':    return bn_modexp_gmp($base, $exp, $mod, $size);
        case 'bcmath': return bn_modexp_bcmath($base, $exp, $mod, $size);
        default:       return bn_modexp_pure($base, $exp, $mod, $size);
    }
}

// --- backend GMP ---
function bn_modexp_gmp($base, $exp, $mod, $size) {
    $b = gmp_init(bin2hex($base) === '' ? '0' : bin2hex($base), 16);
    $e = gmp_init(bin2hex($exp)  === '' ? '0' : bin2hex($exp),  16);
    $m = gmp_init(bin2hex($mod)  === '' ? '0' : bin2hex($mod),  16);
    $r = gmp_powm($b, $e, $m);
    $hex = gmp_strval($r, 16);
    return hex_to_be_padded($hex, $size);
}

// --- backend BCMath (lavora in decimale) ---
function bn_modexp_bcmath($base, $exp, $mod, $size) {
    $b = be_to_dec($base);
    $e = be_to_dec($exp);
    $m = be_to_dec($mod);
    $r = bcpowmod($b, $e, $m);
    return dec_to_be_padded($r, $size);
}

// --- backend PHP puro (word a 16 bit, sicuro su 32/64 bit) ---
function bn_modexp_pure($base, $exp, $mod, $size) {
    $b = bw_from_be($base);
    $e = bw_from_be($exp);
    $m = bw_from_be($mod);
    $r = bw_modexp($b, $e, $m);
    return bw_to_be($r, $size);
}

// ---- helper di conversione condivisi ----

function hex_to_be_padded($hex, $size) {
    if (strlen($hex) % 2 !== 0) { $hex = '0' . $hex; }
    $bin = ($hex === '' || $hex === '0') ? '' : pack('H*', $hex);
    if (strlen($bin) < $size) { $bin = str_repeat("\x00", $size - strlen($bin)) . $bin; }
    return $bin;
}

/** big-endian binario -> stringa decimale (per BCMath). */
function be_to_dec($bytes) {
    $bytes = ltrim($bytes, "\x00");
    if ($bytes === '') { return '0'; }
    $dec = '0';
    $len = strlen($bytes);
    for ($i = 0; $i < $len; $i++) {
        $dec = bcadd(bcmul($dec, '256'), (string)ord($bytes[$i]));
    }
    return $dec;
}

/** stringa decimale -> big-endian binario zero-padded. */
function dec_to_be_padded($dec, $size) {
    $out = '';
    if ($dec === '' ) { $dec = '0'; }
    while (bccomp($dec, '0') > 0) {
        $rem = bcmod($dec, '256');
        $out = chr((int)$rem) . $out;
        $dec = bcdiv($dec, '256', 0);
    }
    if ($out === '') { $out = "\x00"; }
    if (strlen($out) < $size) { $out = str_repeat("\x00", $size - strlen($out)) . $out; }
    return $out;
}

// ---- bigint PHP puro: array di word 16-bit, little-endian (indice 0 = LSW) ----

function bw_from_be($bytes) {
    $bytes = ltrim($bytes, "\x00");
    if ($bytes === '') { return array(0); }
    $len = strlen($bytes);
    $words = array();
    $i = $len;
    while ($i > 0) {
        $lo = ord($bytes[$i-1]);
        $hi = ($i-2 >= 0) ? ord($bytes[$i-2]) : 0;
        $words[] = $lo | ($hi << 8);
        $i -= 2;
    }
    bw_trim($words);
    return $words;
}

function bw_to_be($words, $size) {
    $out = '';
    foreach ($words as $w) {
        $out .= chr($w & 0xFF) . chr(($w >> 8) & 0xFF);
    }
    $out = strrev($out);
    $out = ltrim($out, "\x00");
    if ($out === '') { $out = "\x00"; }
    if (strlen($out) < $size) { $out = str_repeat("\x00", $size - strlen($out)) . $out; }
    return $out;
}

function bw_trim(&$a) {
    while (count($a) > 1 && $a[count($a)-1] === 0) { array_pop($a); }
}

function bw_cmp($a, $b) {
    $na = count($a); $nb = count($b);
    if ($na !== $nb) { return $na < $nb ? -1 : 1; }
    for ($i = $na - 1; $i >= 0; $i--) {
        if ($a[$i] !== $b[$i]) { return $a[$i] < $b[$i] ? -1 : 1; }
    }
    return 0;
}

function bw_sub($a, $b) { // a - b, assume a >= b
    $n = count($a); $nb = count($b);
    $res = array(); $borrow = 0;
    for ($i = 0; $i < $n; $i++) {
        $bv = ($i < $nb) ? $b[$i] : 0;
        $d = $a[$i] - $bv - $borrow;
        if ($d < 0) { $d += 0x10000; $borrow = 1; } else { $borrow = 0; }
        $res[$i] = $d;
    }
    bw_trim($res);
    return $res;
}

function bw_mul($a, $b) {
    $na = count($a); $nb = count($b);
    $res = array_fill(0, $na + $nb, 0);
    for ($i = 0; $i < $na; $i++) {
        $carry = 0; $ai = $a[$i];
        for ($j = 0; $j < $nb; $j++) {
            $cur = $res[$i+$j] + $ai * $b[$j] + $carry;
            $res[$i+$j] = $cur & 0xFFFF;
            $carry = $cur >> 16;
        }
        $res[$i + $nb] += $carry;
    }
    bw_trim($res);
    return $res;
}

function bw_shl1($a) {
    $res = array(); $carry = 0;
    foreach ($a as $w) {
        $v = ($w << 1) | $carry;
        $res[] = $v & 0xFFFF;
        $carry = ($v >> 16) & 1;
    }
    if ($carry) { $res[] = 1; }
    bw_trim($res);
    return $res;
}

function bw_testbit($a, $bit) {
    $wi = $bit >> 4; $bi = $bit & 15;
    if ($wi >= count($a)) { return 0; }
    return ($a[$wi] >> $bi) & 1;
}

function bw_bitlen($a) {
    for ($i = count($a) - 1; $i >= 0; $i--) {
        if ($a[$i] !== 0) {
            $w = $a[$i]; $b = 0;
            while ($w > 0) { $w >>= 1; $b++; }
            return $i * 16 + $b;
        }
    }
    return 0;
}

function bw_mod($a, $m) {
    if (bw_cmp($a, $m) < 0) { return $a; }
    $rem = array(0);
    $bits = bw_bitlen($a);
    for ($i = $bits - 1; $i >= 0; $i--) {
        $rem = bw_shl1($rem);
        if (bw_testbit($a, $i)) { $rem[0] |= 1; }
        if (bw_cmp($rem, $m) >= 0) { $rem = bw_sub($rem, $m); }
    }
    bw_trim($rem);
    return $rem;
}

function bw_modexp($base, $exp, $m) {
    $result = array(1);
    $base = bw_mod($base, $m);
    $bits = bw_bitlen($exp);
    for ($i = 0; $i < $bits; $i++) {
        if (bw_testbit($exp, $i)) {
            $result = bw_mod(bw_mul($result, $base), $m);
        }
        $base = bw_mod(bw_mul($base, $base), $m);
    }
    return $result;
}

/** Confronto big-endian (interi non negativi): -1/0/1. */
function be_cmp_simple($a, $b) {
    $a = ltrim($a, "\x00");
    $b = ltrim($b, "\x00");
    if (strlen($a) !== strlen($b)) {
        return strlen($a) < strlen($b) ? -1 : 1;
    }
    $c = strcmp($a, $b);
    if ($c === 0) { return 0; }
    return $c < 0 ? -1 : 1;
}

// ============================================================
//  RSA-PKCS1v15-SHA256 verify
// ============================================================

function rsa_pkcs1_verify($signature, $modulus, $exponent, $expectedHash, $digestInfoPrefix) {
    $sig = ltrim_sign($signature);
    $mod = ltrim_sign($modulus);

    // sig deve essere 0 < sig < modulus
    if (be_cmp_simple($sig, $mod) >= 0 || ltrim($sig, "\x00") === '') {
        return false;
    }

    $k  = strlen($mod);
    $em = bn_modexp_be($signature, $exponent, $modulus, $k);

    // EM = 0x00 0x01 PS(0xFF..) 0x00 DigestInfo
    if (strlen($em) < 11 || $em[0] !== "\x00" || $em[1] !== "\x01") {
        return false;
    }
    $i = 2;
    $L = strlen($em);
    while ($i < $L && $em[$i] === "\xFF") {
        $i++;
    }
    if ($i < 10 || $i >= $L || $em[$i] !== "\x00") {
        return false;
    }
    $i++;

    $tail = substr($em, $i);
    $want = $digestInfoPrefix . $expectedHash;
    return hash_equals_compat($want, $tail);
}

/** hash_equals esiste da 5.6; fallback constant-time per 5.4/5.5. */
function hash_equals_compat($a, $b) {
    if (function_exists('hash_equals')) {
        return hash_equals($a, $b);
    }
    if (!is_string($a) || !is_string($b)) {
        return false;
    }
    $la = strlen($a);
    $lb = strlen($b);
    if ($la !== $lb) {
        return false;
    }
    $diff = 0;
    for ($i = 0; $i < $la; $i++) {
        $diff |= ord($a[$i]) ^ ord($b[$i]);
    }
    return $diff === 0;
}

// ============================================================
//  PARSING P7M  (restituisce array associativo "result")
// ============================================================

function new_result() {
    return array(
        'valid'          => false,
        'error'          => '',
        'log'            => array(),
        'signerCN'       => null,
        'signerOrg'      => null,
        'signerGiven'    => null,
        'signerSurname'  => null,
        'signerSerial'   => null,
        'codiceFiscale'  => null,
        'subjectDN'      => array(),
        'issuerDN'       => array(),
        'certSha256'     => null,
        'certNotBefore'  => null,
        'certNotAfter'   => null,
        'signingTime'    => null,
        'payloadSha256'  => null,
        'payloadLen'     => 0,
        'contentPreview' => null,
        'contentTruncated' => false,
        'sigAlgo'        => '',
    );
}

/** True se il servizio gira in "modalita proprietario" (OWNER_CF configurato). */
function is_owner_mode() {
    return trim(OWNER_CF) !== '';
}

function result_is_owner($r) {
    // In modalita universale non esiste un firmatario "proprietario".
    if (!is_owner_mode()) {
        return false;
    }
    return $r['valid']
        && $r['codiceFiscale'] !== null
        && strtoupper($r['codiceFiscale']) === strtoupper(OWNER_CF);
}

/**
 * Genera un'anteprima testuale di un payload binario.
 * Ritorna null se non sembra testo; altrimenti array('text'=>..., 'truncated'=>bool).
 * Tronca a $max byte e rimuove un eventuale carattere UTF-8 spezzato in coda.
 */
function make_text_preview($payload, $max) {
    $len = strlen($payload);
    // un payload con NUL non e testo leggibile
    if (strpos($payload, "\x00") !== false) {
        return null;
    }
    $truncated = false;
    $slice = $payload;
    if ($len > $max) {
        $slice = substr($payload, 0, $max);
        $truncated = true;
        // rimuovi byte di continuazione UTF-8 troncati alla fine
        $slice = utf8_trim_incomplete($slice);
    }
    // verifica che il pezzo sia UTF-8 valido; se non lo e, non e un'anteprima utile
    if (preg_match('//u', $slice) !== 1) {
        return null;
    }
    return array('text' => $slice, 'truncated' => $truncated);
}

/** Rimuove una sequenza UTF-8 multibyte incompleta in coda alla stringa. */
function utf8_trim_incomplete($s) {
    $len = strlen($s);
    if ($len === 0) { return $s; }
    // scorri indietro al massimo 3 byte cercando l'inizio di una sequenza multibyte
    for ($back = 0; $back < 4 && $back < $len; $back++) {
        $i = $len - 1 - $back;
        $c = ord($s[$i]);
        if (($c & 0xC0) === 0x80) {
            // byte di continuazione: continua a risalire
            continue;
        }
        // trovato un byte iniziale (o ASCII)
        if (($c & 0x80) === 0) {
            // ASCII: nulla da tagliare
            return $s;
        }
        // byte leader: quanti byte servono?
        if (($c & 0xE0) === 0xC0)      { $need = 2; }
        elseif (($c & 0xF0) === 0xE0)  { $need = 3; }
        elseif (($c & 0xF8) === 0xF0)  { $need = 4; }
        else                           { $need = 1; }
        $have = $back + 1;
        if ($have < $need) {
            // sequenza incompleta: tagliala
            return substr($s, 0, $i);
        }
        return $s;
    }
    return $s;
}

function extract_cf($serial) {
    if ($serial === null) {
        return null;
    }
    $s = strtoupper(trim($serial));
    if (preg_match('/(?:TINIT-|IT:)?([A-Z]{6}\d{2}[A-Z]\d{2}[A-Z]\d{3}[A-Z])/', $s, $m)) {
        return $m[1];
    }
    return null;
}

/**
 * Parsa un ASN.1 time (UTCTime 0x17 o GeneralizedTime 0x18) e lo normalizza a UTC.
 *
 * Lo standard CMS/CAdES impone la forma "Z" (UTC), che e il caso normale. Per
 * tolleranza verso file fuori standard (vecchie CA locali) accettiamo anche un
 * offset esplicito "+HHMM"/"-HHMM", convertendolo a UTC, e UTCTime senza secondi.
 * Se la stringa resta non interpretabile si restituisce null: la firma rimane
 * comunque verificabile, perche il signing time e solo informativo.
 */
function parse_asn1_time($tag, $raw) {
    $raw = trim($raw);

    if ($tag === 0x17) { // UTCTime: YY MM DD HH MM [SS] (Z | ±HHMM)
        // con secondi
        if (preg_match('/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(Z|[+\-]\d{4})$/', $raw, $m)) {
            $yy = intval($m[1]);
            $year = ($yy >= 50) ? 1900 + $yy : 2000 + $yy;
            return asn1_time_to_utc($year, $m[2], $m[3], $m[4], $m[5], $m[6], $m[7]);
        }
        // senza secondi (raro ma ammesso): YY MM DD HH MM (Z | ±HHMM)
        if (preg_match('/^(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(Z|[+\-]\d{4})$/', $raw, $m)) {
            $yy = intval($m[1]);
            $year = ($yy >= 50) ? 1900 + $yy : 2000 + $yy;
            return asn1_time_to_utc($year, $m[2], $m[3], $m[4], $m[5], '00', $m[6]);
        }
        return null;
    }

    if ($tag === 0x18) { // GeneralizedTime: YYYY MM DD HH MM SS (Z | ±HHMM)
        if (preg_match('/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\.\d+)?(Z|[+\-]\d{4})$/', $raw, $m)) {
            return asn1_time_to_utc(intval($m[1]), $m[2], $m[3], $m[4], $m[5], $m[6], $m[7]);
        }
        return null;
    }

    return null;
}

/**
 * Compone una stringa "YYYY-MM-DD HH:MM:SS UTC" applicando l'eventuale offset.
 * $zone e "Z" oppure "+HHMM"/"-HHMM".
 */
function asn1_time_to_utc($year, $mon, $day, $hh, $mm, $ss, $zone) {
    if ($zone === 'Z') {
        return sprintf('%04d-%02d-%02d %02d:%02d:%02d UTC',
            $year, intval($mon), intval($day), intval($hh), intval($mm), intval($ss));
    }
    // offset esplicito: converti a UTC sottraendo l'offset
    $sign  = ($zone[0] === '-') ? -1 : 1;
    $offH  = intval(substr($zone, 1, 2));
    $offM  = intval(substr($zone, 3, 2));
    $ts = gmmktime(intval($hh), intval($mm), intval($ss), intval($mon), intval($day), $year);
    if ($ts === false) {
        return null;
    }
    $ts -= $sign * ($offH * 3600 + $offM * 60);
    return gmdate('Y-m-d H:i:s', $ts) . ' UTC';
}

function parse_dn($d, $n, $name) {
    $out = array();
    $map = dn_oid_map();
    foreach (der_children($d, $n, $name) as $rdn) {
        if ($rdn['tag'] !== 0x31) { continue; }
        foreach (der_children($d, $n, $rdn) as $atv) {
            if ($atv['tag'] !== 0x30) { continue; }
            $kids = der_children($d, $n, $atv);
            if (count($kids) < 2) { continue; }
            $oid = der_oid($d, $kids[0]);
            $val = der_str($d, $kids[1]);
            $label = isset($map[$oid]) ? $map[$oid] : $oid;
            $out[] = array('type' => $label, 'value' => $val);
        }
    }
    return $out;
}

function dn_get($dn, $type) {
    foreach ($dn as $e) {
        if ($e['type'] === $type) { return $e['value']; }
    }
    return null;
}

function dn_to_string($dn) {
    $parts = array();
    foreach ($dn as $e) {
        $parts[] = $e['type'] . '=' . $e['value'];
    }
    return implode(', ', $parts);
}

function verify_p7m($data) {
    $r = new_result();
    $d = $data;
    $n = strlen($data);

    try {
        // ContentInfo ::= SEQUENCE { contentType OID, content [0] EXPLICIT }
        $outer = der_expect($d, $n, 0, 0x30);
        $ci = der_children($d, $n, $outer);
        if (empty($ci) || der_oid($d, $ci[0]) !== OID_SIGNED_DATA) {
            throw new Exception('not a pkcs7-signedData');
        }
        $r['log'][] = 'ContentInfo: pkcs7-signedData';

        $explicit = $ci[1];
        if ($explicit['tag'] !== 0xA0) {
            throw new Exception('[0] EXPLICIT missing');
        }
        $sd = der_expect($d, $n, $explicit['start'], 0x30);
        $sdKids = der_children($d, $n, $sd);

        $idx = 0;
        $version = $sdKids[$idx++];
        $r['log'][] = 'SignedData version: ' . be_to_int(der_str($d, $version));

        $digestAlgs = $sdKids[$idx++];
        foreach (der_children($d, $n, $digestAlgs) as $da) {
            $daKids = der_children($d, $n, $da);
            if (!empty($daKids) && $daKids[0]['tag'] === 0x06) {
                $r['log'][] = 'SignedData digestAlgorithms: ' . oid_name(der_oid($d, $daKids[0]));
                break;
            }
        }

        // encapContentInfo
        $encap = $sdKids[$idx++];
        $encapKids = der_children($d, $n, $encap);
        $payload = null;
        if (count($encapKids) > 1 && $encapKids[1]['tag'] === 0xA0) {
            $octet = der_expect($d, $n, $encapKids[1]['start'], 0x04);
            $payload = der_str($d, $octet);
        }
        if ($payload !== null) {
            $r['payloadLen']    = strlen($payload);
            $r['payloadSha256'] = hash('sha256', $payload);
            $r['log'][] = 'Encapsulated payload: ' . $r['payloadLen'] . ' bytes';
            $r['log'][] = 'Payload SHA-256: ' . $r['payloadSha256'];
            // Anteprima: mostra l'incipit testuale (max 2048 byte). Per file piu grandi
            // tronca invece di nascondere, cosi si legge comunque l'inizio del documento.
            $preview = make_text_preview($payload, 2048);
            if ($preview !== null) {
                $r['contentPreview'] = $preview['text'];
                $r['contentTruncated'] = $preview['truncated'];
            }
        } else {
            $r['log'][] = 'Payload: detached (not encapsulated)';
        }

        // [certificates] [0] IMPLICIT
        $certNode = null;
        for (; $idx < count($sdKids); $idx++) {
            if ($sdKids[$idx]['tag'] === 0xA0) {
                $certNode = $sdKids[$idx];
                $idx++;
                break;
            }
            if ($sdKids[$idx]['tag'] === 0x31) {
                break;
            }
        }

        $modulus = null;
        $exponent = null;
        if ($certNode !== null) {
            $cert = der_read($d, $n, $certNode['start']);
            $rawCert = substr($d, $cert['hstart'], $cert['hlen'] + $cert['len']);
            $r['certSha256'] = hash('sha256', $rawCert);
            $r['log'][] = 'Certificate found: ' . strlen($rawCert) . ' bytes';
            $r['log'][] = 'Certificate SHA-256: ' . $r['certSha256'];
            parse_certificate($d, $n, $cert, $r, $modulus, $exponent);
        } else {
            $r['log'][] = 'No encapsulated certificate';
        }

        // signerInfos SET
        $siSet = null;
        for ($j = $idx - 1; $j < count($sdKids); $j++) {
            if (isset($sdKids[$j]) && $sdKids[$j]['tag'] === 0x31) {
                $siSet = $sdKids[$j];
                break;
            }
        }
        if ($siSet === null) {
            $siSet = end($sdKids);
        }
        if ($siSet === null || $siSet['tag'] !== 0x31) {
            throw new Exception('signerInfos SET missing');
        }

        $siList = der_children($d, $n, $siSet);
        if (empty($siList)) {
            throw new Exception('no SignerInfo');
        }
        $si = $siList[0];
        if ($si['tag'] !== 0x30) {
            throw new Exception('SignerInfo is not a SEQUENCE');
        }

        process_signer_info($d, $n, $si, $r, $modulus, $exponent, $payload);

    } catch (Exception $e) {
        $r['valid'] = false;
        $r['error'] = $e->getMessage();
        $r['log'][] = 'ERROR: ' . $e->getMessage();
    }

    return $r;
}

function parse_certificate($d, $n, $cert, &$r, &$modulus, &$exponent) {
    $tbs = der_expect($d, $n, $cert['start'], 0x30);
    $tbsKids = der_children($d, $n, $tbs);

    $p = 0;
    if (isset($tbsKids[$p]) && $tbsKids[$p]['tag'] === 0xA0) { $p++; }
    $p++; // serialNumber
    $p++; // signature AlgId
    $issuer   = $tbsKids[$p++];
    $validity = $tbsKids[$p++];
    $subject  = $tbsKids[$p++];
    $spki     = $tbsKids[$p++];

    $r['issuerDN']  = parse_dn($d, $n, $issuer);
    $r['subjectDN'] = parse_dn($d, $n, $subject);

    $vKids = der_children($d, $n, $validity);
    if (count($vKids) >= 2) {
        $r['certNotBefore'] = parse_asn1_time($vKids[0]['tag'], der_str($d, $vKids[0]));
        $r['certNotAfter']  = parse_asn1_time($vKids[1]['tag'], der_str($d, $vKids[1]));
    }

    $r['signerCN']      = dn_get($r['subjectDN'], 'CN');
    $r['signerGiven']   = dn_get($r['subjectDN'], 'givenName');
    $r['signerSurname'] = dn_get($r['subjectDN'], 'surname');
    $r['signerSerial']  = dn_get($r['subjectDN'], 'serialNumber');
    $r['signerOrg']     = dn_get($r['subjectDN'], 'O');
    $r['codiceFiscale'] = extract_cf($r['signerSerial']);

    if ($r['signerCN'])      { $r['log'][] = 'Subject CN: ' . $r['signerCN']; }
    if ($r['signerOrg'])     { $r['log'][] = 'Subject O: ' . $r['signerOrg']; }
    if ($r['signerSerial'])  { $r['log'][] = 'Subject serialNumber: ' . $r['signerSerial']; }
    if ($r['codiceFiscale']) { $r['log'][] = 'Fiscal code: ' . $r['codiceFiscale']; }
    $r['log'][] = 'Issuer: ' . dn_to_string($r['issuerDN']);
    if ($r['certNotBefore']) { $r['log'][] = 'Valid from: ' . $r['certNotBefore']; }
    if ($r['certNotAfter'])  { $r['log'][] = 'Valid to:   ' . $r['certNotAfter']; }

    $spkiKids = der_children($d, $n, $spki);
    $algId = $spkiKids[0];
    $algKids = der_children($d, $n, $algId);
    $algOid = der_oid($d, $algKids[0]);
    if ($algOid !== OID_RSA_ENC) {
        $r['log'][] = 'WARNING: non-RSA key (' . $algOid . '), verification not supported';
        return;
    }
    $bitstr = $spkiKids[1];
    $rsaKeyDer = der_str($d, $bitstr);
    $rsaKeyDer = substr($rsaKeyDer, 1); // scarta unused-bits byte
    $rn = strlen($rsaKeyDer);
    $rsaSeq = der_expect($rsaKeyDer, $rn, 0, 0x30);
    $rsaKids = der_children($rsaKeyDer, $rn, $rsaSeq);
    $modInt = der_str($rsaKeyDer, $rsaKids[0]);
    $expInt = der_str($rsaKeyDer, $rsaKids[1]);
    $modulus  = ltrim_sign($modInt);
    $exponent = ltrim_sign($expInt);
    $r['log'][] = 'RSA public key: ' . (strlen($modulus) * 8) . ' bit';
}

function process_signer_info($d, $n, $si, &$r, $modulus, $exponent, $payload) {
    $kids = der_children($d, $n, $si);
    $p = 0;
    $p++; // version
    $p++; // sid
    $digestAlg = $kids[$p++];
    $digestAlgKids = der_children($d, $n, $digestAlg);
    $digestOid = !empty($digestAlgKids) ? der_oid($d, $digestAlgKids[0]) : '';

    // Risolvi l'algoritmo di digest tramite il registro.
    $dig = digest_lookup($digestOid);
    if ($dig === null) {
        // Algoritmo non supportato: errore ESPLICITO, non un falso "firma non valida".
        $r['valid'] = false;
        $r['error'] = 'unsupported digest algorithm (OID ' . ($digestOid !== '' ? $digestOid : '?') . ')';
        $r['log'][] = 'Digest algorithm OID: ' . ($digestOid !== '' ? $digestOid : '(none)');
        $r['log'][] = 'ERROR: unsupported digest algorithm, cannot verify';
        return;
    }
    $hashName   = $dig['name'];
    $digPrefix  = $dig['prefix'];
    $r['log'][] = 'Digest algorithm: ' . $dig['label'] . ($dig['weak'] ? ' (deprecated)' : '');

    $signedAttrs = null;
    if (isset($kids[$p]) && $kids[$p]['tag'] === 0xA0) {
        $signedAttrs = $kids[$p++];
    }

    $sigAlg = $kids[$p++];
    $sigAlgKids = der_children($d, $n, $sigAlg);
    $sigOid = der_oid($d, $sigAlgKids[0]);
    if ($sigOid === OID_RSA_ENC && $digestOid !== '') {
        $r['sigAlgo'] = $dig['label'] . ' + RSA (PKCS#1 v1.5)';
    } else {
        $r['sigAlgo'] = oid_name($sigOid);
    }
    $r['log'][] = 'Signature algorithm: ' . $r['sigAlgo'];

    $sigOctet = $kids[$p++];
    if ($sigOctet['tag'] !== 0x04) {
        throw new Exception('signature OCTET STRING missing');
    }
    $signature = der_str($d, $sigOctet);
    $r['log'][] = 'Signature: ' . strlen($signature) . ' bytes';

    if ($signedAttrs !== null) {
        $messageDigest = null;
        foreach (der_children($d, $n, $signedAttrs) as $attr) {
            if ($attr['tag'] !== 0x30) { continue; }
            $aKids = der_children($d, $n, $attr);
            $aoid = der_oid($d, $aKids[0]);
            if (!isset($aKids[1])) { continue; }
            $vals = der_children($d, $n, $aKids[1]);
            if (empty($vals)) { continue; }
            if ($aoid === OID_MESSAGE_DIGEST) {
                $messageDigest = der_str($d, $vals[0]);
            } elseif ($aoid === OID_SIGNING_TIME) {
                $r['signingTime'] = parse_asn1_time($vals[0]['tag'], der_str($d, $vals[0]));
                if ($r['signingTime']) { $r['log'][] = 'Signing time: ' . $r['signingTime']; }
            }
        }

        if ($messageDigest === null) {
            throw new Exception('messageDigest absent in signedAttrs');
        }
        $r['log'][] = 'messageDigest declared: ' . bin2hex($messageDigest);

        if ($payload !== null) {
            $calc = hash($hashName, $payload, true);
            if (!hash_equals_compat($calc, $messageDigest)) {
                throw new Exception('messageDigest does not match content hash');
            }
            $r['log'][] = 'messageDigest verified against payload: OK';
        } else {
            $r['log'][] = 'Detached payload: messageDigest cannot be verified against content';
        }

        // l'hash firmato e quello dei signedAttrs ri-tagati come SET (0x31)
        $saContent = der_str($d, $signedAttrs);
        $lenHeader = substr($d, $signedAttrs['hstart'] + 1, $signedAttrs['hlen'] - 1);
        $saReTagged = "\x31" . $lenHeader . $saContent;
        $hashToVerify = hash($hashName, $saReTagged, true);
    } else {
        if ($payload === null) {
            throw new Exception('no signedAttrs and no payload: cannot verify');
        }
        $hashToVerify = hash($hashName, $payload, true);
        $r['log'][] = 'No signedAttrs: signature directly over payload';
    }

    if ($modulus === null || $exponent === null) {
        throw new Exception('RSA public key not available for verification');
    }

    $ok = rsa_pkcs1_verify($signature, $modulus, $exponent, $hashToVerify, $digPrefix);
    if ($ok) {
        $r['valid'] = true;
        $r['log'][] = 'Cryptographic verification RSA-PKCS1v15-' . $dig['label'] . ': VALID';
    } else {
        $r['valid'] = false;
        $r['error'] = 'invalid RSA signature';
        $r['log'][] = 'Cryptographic RSA verification: FAILED';
    }
}

// ============================================================
//  FETCH con anti-SSRF
// ============================================================

function is_private_ip($ip) {
    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false) {
        return true;
    }
    return false;
}

function assert_safe_url($url) {
    $parts = parse_url($url);
    if ($parts === false || empty($parts['scheme']) || empty($parts['host'])) {
        throw new Exception('invalid URL');
    }
    $scheme = strtolower($parts['scheme']);
    if ($scheme !== 'http' && $scheme !== 'https') {
        throw new Exception('scheme not allowed: ' . $scheme . ' (http/https only)');
    }
    $host = $parts['host'];

    $ips = @gethostbynamel($host);
    if ($ips === false || empty($ips)) {
        $ips = array();
        if (function_exists('dns_get_record')) {
            $aaaa = @dns_get_record($host, DNS_AAAA);
            if ($aaaa) {
                foreach ($aaaa as $rec) {
                    if (!empty($rec['ipv6'])) { $ips[] = $rec['ipv6']; }
                }
            }
        }
        if (empty($ips)) {
            throw new Exception('host not resolvable: ' . $host);
        }
    }
    foreach ($ips as $ip) {
        if (is_private_ip($ip)) {
            throw new Exception('host resolves to private/reserved IP: ' . $ip);
        }
    }
    return $scheme;
}

function resolve_url($base, $rel) {
    if (parse_url($rel, PHP_URL_SCHEME) !== null) {
        return $rel;
    }
    $b = parse_url($base);
    $scheme = isset($b['scheme']) ? $b['scheme'] : 'https';
    $host   = isset($b['host']) ? $b['host'] : '';
    $port   = isset($b['port']) ? ':' . $b['port'] : '';
    if (strlen($rel) > 0 && $rel[0] === '/') {
        return "$scheme://$host$port$rel";
    }
    $path = isset($b['path']) ? $b['path'] : '/';
    $dir  = substr($path, 0, strrpos($path, '/') + 1);
    return "$scheme://$host$port$dir$rel";
}

/**
 * Scarica un URL. Usa cURL se disponibile, altrimenti fopen wrapper.
 * Restituisce array(data, finalUrl, chain). Lancia Exception in errore.
 */
function fetch_url($url) {
    if (function_exists('curl_init')) {
        return fetch_url_curl($url);
    }
    return fetch_url_fopen($url);
}

function fetch_url_curl($url) {
    $chain = array();
    $current = $url;

    for ($hop = 0; $hop <= MAX_REDIRECTS; $hop++) {
        assert_safe_url($current);
        $chain[] = $current;

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $current);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false); // redirect manuali
        curl_setopt($ch, CURLOPT_HEADER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, FETCH_TIMEOUT);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, FETCH_TIMEOUT);
        curl_setopt($ch, CURLOPT_USERAGENT, USER_AGENT_STR);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 2);

        $resp = curl_exec($ch);
        if ($resp === false) {
            $err = curl_error($ch);
            curl_close($ch);
            throw new Exception('cURL: ' . $err . ' on ' . $current);
        }
        $status      = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $headerSize  = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
        curl_close($ch);

        $rawHeaders = substr($resp, 0, $headerSize);
        $body       = substr($resp, $headerSize);

        if (strlen($body) > MAX_BYTES) {
            throw new Exception('file too large (> ' . MAX_BYTES . ' bytes)');
        }

        if ($status >= 300 && $status < 400) {
            $location = null;
            foreach (explode("\n", $rawHeaders) as $h) {
                if (stripos($h, 'Location:') === 0) {
                    $location = trim(substr($h, 9));
                }
            }
            if ($location !== null) {
                $current = resolve_url($current, $location);
                continue;
            }
        }

        if ($status !== 200) {
            throw new Exception('HTTP ' . $status . ' on ' . $current);
        }

        return array($body, $current, $chain);
    }

    throw new Exception('too many redirects (> ' . MAX_REDIRECTS . ')');
}

function fetch_url_fopen($url) {
    if (!ini_get('allow_url_fopen')) {
        throw new Exception('allow_url_fopen disabled and cURL absent: cannot download');
    }
    $chain = array();
    $current = $url;

    for ($hop = 0; $hop <= MAX_REDIRECTS; $hop++) {
        assert_safe_url($current);
        $chain[] = $current;

        $opts = array(
            'http' => array(
                'method'          => 'GET',
                'follow_location' => 0,
                'timeout'         => FETCH_TIMEOUT,
                'ignore_errors'   => true,
                'user_agent'      => USER_AGENT_STR,
                'header'          => "Accept: */*\r\n",
            ),
            'ssl' => array(
                'verify_peer'      => true,
                'verify_peer_name' => true,
            ),
        );
        $ctx = stream_context_create($opts);
        $fp = @fopen($current, 'rb', false, $ctx);
        if ($fp === false) {
            throw new Exception('cannot open: ' . $current);
        }
        $meta = stream_get_meta_data($fp);
        $headers = isset($meta['wrapper_data']) ? $meta['wrapper_data'] : array();
        $status = 0;
        $location = null;
        $contentLength = null;
        foreach ($headers as $h) {
            if (preg_match('#^HTTP/\S+\s+(\d{3})#', $h, $m)) {
                $status = intval($m[1]);
            } elseif (stripos($h, 'Location:') === 0) {
                $location = trim(substr($h, 9));
            } elseif (stripos($h, 'Content-Length:') === 0) {
                $contentLength = intval(trim(substr($h, 15)));
            }
        }
        if ($contentLength !== null && $contentLength > MAX_BYTES) {
            fclose($fp);
            throw new Exception('file too large: ' . $contentLength . ' bytes');
        }
        if ($status >= 300 && $status < 400 && $location !== null) {
            fclose($fp);
            $current = resolve_url($current, $location);
            continue;
        }
        if ($status !== 200) {
            fclose($fp);
            throw new Exception('HTTP ' . $status . ' on ' . $current);
        }
        $data = '';
        while (!feof($fp)) {
            $chunk = fread($fp, 65536);
            if ($chunk === false) { break; }
            $data .= $chunk;
            if (strlen($data) > MAX_BYTES) {
                fclose($fp);
                throw new Exception('file exceeds ' . MAX_BYTES . ' bytes');
            }
        }
        fclose($fp);
        return array($data, $current, $chain);
    }
    throw new Exception('too many redirects (> ' . MAX_REDIRECTS . ')');
}

// ============================================================
//  OUTPUT
// ============================================================

function hh($s) {
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

function render_json($r, $sourceUrl, $fileSha256) {
    header('Content-Type: application/json; charset=utf-8');
    $out = array(
        'valid'              => $r['valid'],
        'isOwner'            => result_is_owner($r),
        'error'              => $r['error'] !== '' ? $r['error'] : null,
        'signer'             => $r['signerCN'],
        'organization'       => $r['signerOrg'],
        'givenName'          => $r['signerGiven'],
        'surname'            => $r['signerSurname'],
        'serialNumber'       => $r['signerSerial'],
        'codiceFiscale'      => $r['codiceFiscale'],
        'subject'            => dn_to_string($r['subjectDN']),
        'issuer'             => dn_to_string($r['issuerDN']),
        'certNotBefore'      => $r['certNotBefore'],
        'certNotAfter'       => $r['certNotAfter'],
        'certificateSha256'  => $r['certSha256'],
        'signatureAlgorithm' => $r['sigAlgo'],
        'signingTime'        => $r['signingTime'],
        'payloadSha256'      => $r['payloadSha256'],
        'payloadLength'      => $r['payloadLen'],
        'sourceUrl'          => $sourceUrl,
        'downloadedSha256'   => $fileSha256,
    );
    $flags = 0;
    if (defined('JSON_PRETTY_PRINT'))     { $flags |= JSON_PRETTY_PRINT; }
    if (defined('JSON_UNESCAPED_SLASHES')){ $flags |= JSON_UNESCAPED_SLASHES; }
    if (defined('JSON_UNESCAPED_UNICODE')){ $flags |= JSON_UNESCAPED_UNICODE; }
    echo json_encode($out, $flags);
}

function render_row($label, $value) {
    if ($value === null || $value === '') { return; }
    echo '<dt>' . hh($label) . '</dt><dd>' . hh($value) . '</dd>';
}

function render_html($r, $sourceUrl, $fileSha256, $chain) {
    header('Content-Type: text/html; charset=utf-8');

    if (result_is_owner($r)) {
        $bannerClass = 'owner';
        // Se OWNER_LABEL e stato lasciato vuoto, ripiega sul nome del firmatario.
        $label = trim(OWNER_LABEL) !== '' ? OWNER_LABEL : ($r['signerCN'] !== null ? $r['signerCN'] : $r['codiceFiscale']);
        $bannerBig   = '&#10004; ' . t('banner_owner') . ' ' . strtoupper($label);
        $bannerSub   = sprintf(t('banner_ownsub'), hh($r['codiceFiscale']));
    } elseif ($r['valid']) {
        $bannerClass = 'valid';
        if ($r['signerCN'] !== null) {
            $who = $r['signerCN'];
        } elseif ($r['signerOrg'] !== null) {
            $who = $r['signerOrg'];
        } elseif ($r['codiceFiscale'] !== null) {
            $who = $r['codiceFiscale'];
        } else {
            $who = t('unknown_signer');
        }
        $bannerBig   = '&#10004; ' . t('banner_valid');
        $bannerSub   = sprintf(t('banner_signedby'), hh($who));
    } else {
        $bannerClass = 'invalid';
        $bannerBig   = '&#10008; ' . t('banner_invalid');
        $bannerSub   = hh($r['error'] !== '' ? $r['error'] : t('banner_failed'));
    }

    $lang = detect_lang();
    echo "<!doctype html>\n<html lang=\"" . $lang . "\"><head><meta charset=\"utf-8\">";
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<title>' . t('title') . '</title>';
    echo '<style>
        body { font-family: -apple-system, system-ui, "Segoe UI", sans-serif; max-width: 820px;
               margin: 0 auto; padding: 1.5rem; line-height: 1.5; color: #1a1a1a; }
        .banner { border-radius: 12px; padding: 1.5rem 1.75rem; margin: 1rem 0 1.5rem; }
        .banner .big { font-size: 1.9rem; font-weight: 800; }
        .banner .sub { font-size: 1rem; margin-top: 0.35rem; opacity: 0.92; }
        .owner   { background: #0a7d28; color: #fff; }
        .valid   { background: #1f6f3a; color: #fff; }
        .invalid { background: #9a1b1b; color: #fff; }
        h2 { font-size: 0.95rem; text-transform: uppercase; letter-spacing: 0.06em;
             opacity: 0.6; margin: 1.6rem 0 0.5rem; }
        .grid { display: grid; grid-template-columns: max-content 1fr; gap: 0.35rem 1rem; }
        .grid dt { font-weight: 600; opacity: 0.75; }
        .grid dd { margin: 0; word-break: break-all; }
        pre { background: #f3f3f3; padding: 1rem; border-radius: 8px; overflow-x: auto;
              font-size: 0.85rem; line-height: 1.45; }
        code { font-family: ui-monospace, Menlo, Consolas, monospace; }
        .src { font-size: 0.85rem; word-break: break-all; }
        footer { margin-top: 2rem; font-size: 0.8rem; opacity: 0.6; }
        a { color: inherit; }
    </style></head><body>';

    echo '<div class="banner ' . $bannerClass . '"><div class="big">' . $bannerBig . '</div>';
    echo '<div class="sub">' . $bannerSub . '</div></div>';

    echo '<h2>' . t('signer') . '</h2><dl class="grid">';
    render_row(t('name'),         $r['signerCN']);
    render_row(t('organization'), $r['signerOrg']);
    render_row(t('surname'),      $r['signerSurname']);
    render_row(t('givenname'),    $r['signerGiven']);
    render_row(t('fiscalcode'),   $r['codiceFiscale']);
    render_row(t('serialnumber'), $r['signerSerial']);
    echo '</dl>';

    echo '<h2>' . t('certificate') . '</h2><dl class="grid">';
    render_row(t('issuedby'),    dn_to_string($r['issuerDN']));
    render_row(t('validfrom'),   $r['certNotBefore']);
    render_row(t('validto'),     $r['certNotAfter']);
    render_row(t('certsha'),     $r['certSha256']);
    render_row(t('algorithm'),   $r['sigAlgo']);
    render_row(t('signingtime'), $r['signingTime']);
    echo '</dl>';

    echo '<h2>' . t('signedcontent') . '</h2><dl class="grid">';
    render_row(t('size'),   $r['payloadLen'] > 0 ? $r['payloadLen'] . ' bytes' : null);
    render_row(t('sha256'), $r['payloadSha256']);
    echo '</dl>';

    if ($r['contentPreview'] !== null) {
        $h2 = t('payloadprev');
        if ($r['contentTruncated']) {
            $h2 .= ' <span style="font-weight:400;opacity:0.6;font-size:0.85rem">' . t('truncated') . '</span>';
        }
        echo '<h2>' . $h2 . '</h2><pre><code>' . hh($r['contentPreview']);
        if ($r['contentTruncated']) { echo "\n…"; }
        echo '</code></pre>';
    }

    if ($sourceUrl !== null) {
        echo '<h2>' . t('origin') . '</h2><div class="src">';
        echo t('downloadedfrom') . '<br><a href="' . hh($sourceUrl) . '">' . hh($sourceUrl) . '</a>';
        if ($fileSha256 !== null) {
            echo '<br><br>' . t('downloadedsha') . '<br><code>' . hh($fileSha256) . '</code>';
        }
        if (is_array($chain) && count($chain) > 1) {
            echo '<br><br>' . t('redirectchain') . '<br>';
            foreach ($chain as $u) { echo '&rarr; ' . hh($u) . '<br>'; }
        }
        echo '</div>';
    }

    echo '<h2>' . t('verifylog') . '</h2><pre><code>';
    foreach ($r['log'] as $line) {
        echo hh($line) . "\n";
    }
    echo '</code></pre>';

    echo '<footer>' . t('footer_note') . '<br>';
    echo 'p7m-verify &middot; PHP puro &middot; <a href="https://github.com/zpaqfranz/catpaq">sorgente</a></footer>';

    echo '</body></html>';
}

function render_form() {
    header('Content-Type: text/html; charset=utf-8');
    $lang = detect_lang();
    echo '<!doctype html><html lang="' . $lang . '"><head><meta charset="utf-8">';
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">';
    echo '<title>' . t('title') . '</title><style>
        body { font-family: system-ui, sans-serif; max-width: 640px; margin: 3rem auto; padding: 1rem; line-height: 1.5; }
        input[type=url] { width: 100%; padding: 0.6rem; font-size: 1rem; box-sizing: border-box; }
        button { margin-top: 0.75rem; padding: 0.6rem 1.2rem; font-size: 1rem; cursor: pointer; }
        code { background: #eee; padding: 0.1rem 0.3rem; border-radius: 4px; }
    </style></head><body>';
    echo '<h1>' . t('form_heading') . '</h1>';
    echo '<p>' . t('form_intro') . '</p>';
    echo '<form method="get">';
    echo '<input type="url" name="url" placeholder="https://..." required>';
    echo '<br><button type="submit">' . t('form_button') . '</button></form>';
    echo '<p style="font-size:0.85rem;opacity:0.7;margin-top:2rem">';
    echo t('form_json') . '</p>';
    echo '</body></html>';
}

// ============================================================
//  ENTRYPOINT
// ============================================================

if (php_sapi_name() === 'cli') {
    $file = isset($argv[1]) ? $argv[1] : null;
    if ($file === null) {
        fwrite(STDERR, "Uso: php verify.php <file.p7m>\n");
        exit(1);
    }
    $data = file_get_contents($file);
    $r = verify_p7m($data);
    echo 'valid=' . ($r['valid'] ? 'true' : 'false') . ' owner=' . (result_is_owner($r) ? 'true' : 'false') . "\n";
    if ($r['error']) { echo 'error: ' . $r['error'] . "\n"; }
    echo "--- LOG ---\n";
    foreach ($r['log'] as $l) { echo '  ' . $l . "\n"; }
    exit($r['valid'] ? 0 : 2);
}

$url    = isset($_GET['url'])    ? $_GET['url']    : null;
$format = isset($_GET['format']) ? $_GET['format'] : 'html';

if ($url === null || $url === '') {
    render_form();
    exit;
}

try {
    list($data, $finalUrl, $chain) = fetch_url($url);
} catch (Exception $e) {
    if ($format === 'json') {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(array('valid' => false, 'error' => 'fetch: ' . $e->getMessage()));
    } else {
        $r = new_result();
        $r['error'] = t('download_failed') . $e->getMessage();
        render_html($r, $url, null, array());
    }
    exit;
}

$fileSha = hash('sha256', $data);
$r = verify_p7m($data);

if ($format === 'json') {
    render_json($r, $finalUrl, $fileSha);
} else {
    render_html($r, $finalUrl, $fileSha, $chain);
}
