/*
	newcat.cpp - catpaq Build Tool
	Part of catpaq, Franco Corbelli's zpaq GUI
	build 1

	MIT License
	Copyright (c) 2026 Franco Corbelli

	────────────────────────────────────────────────────────────
	WHAT IT DOES
	────────────────────────────────────────────────────────────
	Automates the full release build cycle for catpaq:

	  1. Reads <BuildNr Value="N"/> from catpaq.lpi and writes N+1
		 back to the file before compiling.
	  2. Computes SHA-256 hashes of zpaqfranz.dll and zpaqfranz.exe.
	  3. Injects those hashes into ufrmmain.pas.
	  4. Recompiles the Lazarus project via lazbuild.
	  5. Strips debug symbols from the resulting executable.
	  6. Writes version.txt (10 lines) ready for updates.
	  7. Prints "Updated to build N" on success.

	────────────────────────────────────────────────────────────
	HOW TO USE
	────────────────────────────────────────────────────────────
	Compile (No external dependencies, compatible with old GCC):
	  g++ -O3 -std=c++11 newcat.cpp -o newcat.exe

	Run with defaults:
	  newcat.exe
	────────────────────────────────────────────────────────────
*/

#ifdef _WIN32
#include <windows.h>
#endif

#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <vector>

// Default configuration based on OS
#ifdef _WIN32
const std::string DEFAULT_catpaq_PATH  = "c:\\zpaqfranz\\catpaq\\";
const std::string DEFAULT_LAZBUILD_PATH= "c:\\lazarus\\lazbuild.exe";
const std::string DEFAULT_STRIP_PATH   = "strip.exe";
#else
const std::string DEFAULT_catpaq_PATH  = "./catpaq/";
const std::string DEFAULT_LAZBUILD_PATH= "lazbuild";
const std::string DEFAULT_STRIP_PATH   = "strip";
#endif

// Runtime configuration
std::string catpaq_PATH;
std::string LAZBUILD_PATH;
std::string STRIP_PATH;
std::string EXE_FILE;
std::string ZPAQFRANZ_EXE;
std::string ZPAQFRANZ_DLL;
std::string SOURCE_FILE;
std::string PROJECT_FILE;

const std::string OUTPUT_FILE= "version.txt";

// Markers in Pascal source for hash replacement
const std::string DLL_HASH_MARKER_START= "// @@DLL_HASH_START@@";
const std::string DLL_HASH_MARKER_END  = "// @@DLL_HASH_END@@";
const std::string EXE_HASH_MARKER_START= "// @@EXE_HASH_START@@";
const std::string EXE_HASH_MARKER_END  = "// @@EXE_HASH_END@@";

namespace sha256
{
const uint32_t k[64]= {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

inline uint32_t ror(uint32_t x, uint32_t n)
{
	return (x >> n) | (x << (32 - n));
}
inline uint32_t ch(uint32_t x, uint32_t y, uint32_t z)
{
	return (x & y) ^ (~x & z);
}
inline uint32_t maj(uint32_t x, uint32_t y, uint32_t z)
{
	return (x & y) ^ (x & z) ^ (y & z);
}
inline uint32_t ep0(uint32_t x)
{
	return ror(x, 2) ^ ror(x, 13) ^ ror(x, 22);
}
inline uint32_t ep1(uint32_t x)
{
	return ror(x, 6) ^ ror(x, 11) ^ ror(x, 25);
}
inline uint32_t sig0(uint32_t x)
{
	return ror(x, 7) ^ ror(x, 18) ^ (x >> 3);
}
inline uint32_t sig1(uint32_t x)
{
	return ror(x, 17) ^ ror(x, 19) ^ (x >> 10);
}

struct Context
{
	uint8_t	 data[64];
	uint32_t datalen = 0;
	uint64_t bitlen	 = 0;
	uint32_t state[8]= {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
};

void transform(Context &ctx, const uint8_t *data)
{
	uint32_t a= ctx.state[0], b= ctx.state[1], c= ctx.state[2], d= ctx.state[3];
	uint32_t e= ctx.state[4], f= ctx.state[5], g= ctx.state[6], h= ctx.state[7];
	uint32_t m[64];

	for (int i= 0, j= 0; i < 16; ++i, j+= 4)
		m[i]= (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | data[j + 3];
	for (int i= 16; i < 64; ++i)
		m[i]= sig1(m[i - 2]) + m[i - 7] + sig0(m[i - 15]) + m[i - 16];

	for (int i= 0; i < 64; ++i)
	{
		uint32_t t1= h + ep1(e) + ch(e, f, g) + k[i] + m[i];
		uint32_t t2= ep0(a) + maj(a, b, c);
		h		   = g;
		g		   = f;
		f		   = e;
		e		   = d + t1;
		d		   = c;
		c		   = b;
		b		   = a;
		a		   = t1 + t2;
	}

	ctx.state[0]+= a;
	ctx.state[1]+= b;
	ctx.state[2]+= c;
	ctx.state[3]+= d;
	ctx.state[4]+= e;
	ctx.state[5]+= f;
	ctx.state[6]+= g;
	ctx.state[7]+= h;
}

void update(Context &ctx, const uint8_t *data, size_t len)
{
	for (size_t i= 0; i < len; ++i)
	{
		ctx.data[ctx.datalen++]= data[i];
		if (ctx.datalen == 64)
		{
			transform(ctx, ctx.data);
			ctx.bitlen+= 512;
			ctx.datalen= 0;
		}
	}
}

void final(Context &ctx, uint8_t *hash)
{
	uint32_t i= ctx.datalen;
	if (ctx.datalen < 56)
	{
		ctx.data[i++]= 0x80;
		while (i < 56)
			ctx.data[i++]= 0x00;
	}
	else
	{
		ctx.data[i++]= 0x80;
		while (i < 64)
			ctx.data[i++]= 0x00;
		transform(ctx, ctx.data);
		std::memset(ctx.data, 0, 56);
	}

	ctx.bitlen+= ctx.datalen * 8;
	ctx.data[63]= ctx.bitlen;
	ctx.data[62]= ctx.bitlen >> 8;
	ctx.data[61]= ctx.bitlen >> 16;
	ctx.data[60]= ctx.bitlen >> 24;
	ctx.data[59]= ctx.bitlen >> 32;
	ctx.data[58]= ctx.bitlen >> 40;
	ctx.data[57]= ctx.bitlen >> 48;
	ctx.data[56]= ctx.bitlen >> 56;
	transform(ctx, ctx.data);

	for (i= 0; i < 4; ++i)
	{
		hash[i]		= (ctx.state[0] >> (24 - i * 8)) & 0xff;
		hash[i + 4] = (ctx.state[1] >> (24 - i * 8)) & 0xff;
		hash[i + 8] = (ctx.state[2] >> (24 - i * 8)) & 0xff;
		hash[i + 12]= (ctx.state[3] >> (24 - i * 8)) & 0xff;
		hash[i + 16]= (ctx.state[4] >> (24 - i * 8)) & 0xff;
		hash[i + 20]= (ctx.state[5] >> (24 - i * 8)) & 0xff;
		hash[i + 24]= (ctx.state[6] >> (24 - i * 8)) & 0xff;
		hash[i + 28]= (ctx.state[7] >> (24 - i * 8)) & 0xff;
	}
}
} // namespace sha256

void PrintHelp(const char *progName)
{
	std::cout << "\ncatpaq Build Tool by Franco Corbelli\n";
	std::cout << "Usage: " << progName << " [options]\n\n";
	std::cout << "Options:\n";
	std::cout << "  -p <path>    Path to catpaq folder  (Default: " << DEFAULT_catpaq_PATH << ")\n";
	std::cout << "  -l <exe>     Path to lazbuild       (Default: " << DEFAULT_LAZBUILD_PATH << ")\n";
	std::cout << "  -s <exe>     Path to strip          (Default: " << DEFAULT_STRIP_PATH << ")\n";
	std::cout << "  -h           Show this help\n\n";
}

std::string EnsureTrailingSlash(const std::string &path)
{
	if (path.empty())
		return path;
	char last= path.back();
	if (last != '\\' && last != '/')
#ifdef _WIN32
		return path + "\\";
#else
		return path + "/";
#endif
	return path;
}

bool FileExists(const std::string &filename)
{
	struct stat buffer;
	return (stat(filename.c_str(), &buffer) == 0 && (buffer.st_mode & S_IFREG));
}

bool DirectoryExists(const std::string &path)
{
	struct stat buffer;
	std::string p= path;
	while (!p.empty() && (p.back() == '\\' || p.back() == '/'))
		p.pop_back();
	return (stat(p.c_str(), &buffer) == 0 && (buffer.st_mode & S_IFDIR));
}

long long GetFileSizeBytes(const std::string &filename)
{
	struct stat buffer;
	return (stat(filename.c_str(), &buffer) == 0) ? buffer.st_size : 0;
}

std::string GetFileDateTime(const std::string &filename)
{
	struct stat result;
	if (stat(filename.c_str(), &result) == 0)
	{
		std::tm			 *tm= std::localtime(&result.st_mtime);
		std::stringstream ss;
		ss << std::setfill('0')
		   << std::setw(2) << tm->tm_mday << "/"
		   << std::setw(2) << tm->tm_mon + 1 << "/"
		   << tm->tm_year + 1900 << " "
		   << std::setw(2) << tm->tm_hour << ":"
		   << std::setw(2) << tm->tm_min << ":"
		   << std::setw(2) << tm->tm_sec;
		return ss.str();
	}
	return "";
}

bool RunProcess(const std::string &cmdLine, const std::string &workingDir, const std::string &label)
{
	std::cout << "  Running: " << cmdLine << "\n";

#ifdef _WIN32
	// Windows API for fine-grained process control
	STARTUPINFOA		si;
	PROCESS_INFORMATION pi;
	ZeroMemory(&si, sizeof(si));
	si.cb= sizeof(si);
	ZeroMemory(&pi, sizeof(pi));

	char cmdBuffer[2048];
	strncpy(cmdBuffer, cmdLine.c_str(), sizeof(cmdBuffer) - 1);
	cmdBuffer[sizeof(cmdBuffer) - 1]= '\0';

	const char *wd= workingDir.empty() ? NULL : workingDir.c_str();

	if (!CreateProcessA(NULL, cmdBuffer, NULL, NULL, FALSE, 0, NULL, wd, &si, &pi))
	{
		std::cerr << "ERROR: CreateProcess failed (" << label << ") - code " << GetLastError() << "\n";
		return false;
	}

	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD exitCode;
	GetExitCodeProcess(pi.hProcess, &exitCode);
	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);

	if (exitCode != 0)
	{
		std::cerr << "ERROR: " << label << " failed with exit code " << exitCode << "\n";
		return false;
	}
#else
	// POSIX fallback using system()
	std::string fullCmd= cmdLine;
	if (!workingDir.empty())
	{
		// Change dir then run command
		fullCmd= "cd \"" + workingDir + "\" && " + cmdLine;
	}

	int exitCode= std::system(fullCmd.c_str());

	if (exitCode != 0)
	{
		std::cerr << "ERROR: " << label << " failed with exit code " << exitCode << "\n";
		return false;
	}
#endif

	std::cout << "  " << label << " completed successfully.\n";
	return true;
}

std::string ReadFileToString(const std::string &filename)
{
	std::ifstream file(filename, std::ios::binary);
	if (!file)
		return "";
	std::stringstream buffer;
	buffer << file.rdbuf();
	return buffer.str();
}

bool WriteStringToFile(const std::string &filename, const std::string &content)
{
	std::ofstream file(filename, std::ios::binary);
	if (!file)
		return false;
	file << content;
	return true;
}

std::string ComputeSHA256(const std::string &filename)
{
	std::ifstream file(filename, std::ios::binary);
	if (!file)
	{
		std::cerr << "ERROR: Cannot open file for hashing: " << filename << "\n";
		return "";
	}

	sha256::Context ctx;
	char			buf[4096];

	while (file.read(buf, sizeof(buf)) || file.gcount() > 0)
	{
		sha256::update(ctx, reinterpret_cast<const uint8_t *>(buf), file.gcount());
	}

	uint8_t hash[32];
	sha256::final(ctx, hash);

	std::stringstream ss;
	for (int i= 0; i < 32; ++i)
		ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];

	return ss.str();
}

bool PreFlightChecks()
{
	bool ok		 = true;
	auto checkDir= [&](const std::string &lbl, const std::string &p)
	{
		if (DirectoryExists(p))
			std::cout << "  [OK]      " << lbl << ": " << p << "\n";
		else
		{
			std::cerr << "  [MISSING] " << lbl << ": " << p << "\n";
			ok= false;
		}
	};
	auto checkFile= [&](const std::string &lbl, const std::string &p)
	{
		if (FileExists(p))
			std::cout << "  [OK]      " << lbl << ": " << p << "\n";
		else
		{
			std::cerr << "  [MISSING] " << lbl << ": " << p << "\n";
			ok= false;
		}
	};

	std::cout << "Pre-flight checks:\n";
	checkDir("catpaq folder", catpaq_PATH);
	checkFile("lazbuild executable", LAZBUILD_PATH);

	if (FileExists(STRIP_PATH))
		std::cout << "  [OK]      strip: " << STRIP_PATH << "\n";
	else
		std::cout << "  [WARN]    strip: " << STRIP_PATH << " not found directly (will rely on PATH)\n";

	checkFile("catpaq.lpi", PROJECT_FILE);
	checkFile("ufrmmain.pas", SOURCE_FILE);
	checkFile("zpaqfranz.exe", ZPAQFRANZ_EXE);
	checkFile("zpaqfranz.dll", ZPAQFRANZ_DLL);

	if (FileExists(EXE_FILE))
		std::cout << "  [OK]      catpaq.exe (existing): " << EXE_FILE << "\n";
	else
		std::cout << "  [INFO]    catpaq.exe not present yet (will be created by build)\n";

	std::cout << "\n";
	return ok;
}

int IncrementLpiBuildNumber(const std::string &lpiFile)
{
	std::string content= ReadFileToString(lpiFile);
	if (content.empty())
		return 0;

	const std::string TAG_OPEN = "<BuildNr Value=\"";
	const std::string TAG_CLOSE= "\"/>";

	size_t startPos= content.find(TAG_OPEN);
	if (startPos == std::string::npos)
		return 0;

	size_t valueStart= startPos + TAG_OPEN.size();
	size_t valueEnd	 = content.find(TAG_CLOSE, valueStart);
	if (valueEnd == std::string::npos)
		return 0;

	std::string oldValueStr= content.substr(valueStart, valueEnd - valueStart);
	for (char c : oldValueStr)
	{
		if (!std::isdigit((unsigned char)c))
			return 0;
	}

	int oldBuild= std::stoi(oldValueStr);
	int newBuild= oldBuild + 1;

	content.replace(valueStart, valueEnd - valueStart, std::to_string(newBuild));

	if (!WriteStringToFile(lpiFile, content))
		return 0;

	std::cout << "  BuildNr: " << oldBuild << " -> " << newBuild << "\n";
	return newBuild;
}

bool InjectHashesIntoSource(const std::string &sourceFile, const std::string &dllHash, const std::string &exeHash)
{
	std::string content= ReadFileToString(sourceFile);
	if (content.empty())
		return false;

	auto replaceSection= [](std::string &text, const std::string &startMarker,
							const std::string &endMarker, const std::string &varName,
							const std::string &hashValue) -> bool
	{
		size_t startPos= text.find(startMarker);
		size_t endPos  = text.find(endMarker);
		if (startPos == std::string::npos || endPos == std::string::npos || endPos <= startPos)
			return false;

		std::string newSection= startMarker + "\n  " + varName + " = '" + hashValue + "';\n  ";
		text				  = text.substr(0, startPos) + newSection + text.substr(endPos);
		return true;
	};

	if (!replaceSection(content, DLL_HASH_MARKER_START, DLL_HASH_MARKER_END, "EXPECTED_DLL_HASH", dllHash))
		return false;
	if (!replaceSection(content, EXE_HASH_MARKER_START, EXE_HASH_MARKER_END, "EXPECTED_EXE_HASH", exeHash))
		return false;

	if (!WriteStringToFile(sourceFile, content))
		return false;

	std::cout << "  Hashes injected into " << sourceFile << "\n";
	return true;
}

int main(int argc, char *argv[])
{
	std::string arg_catpaq_path	 = DEFAULT_catpaq_PATH;
	std::string arg_lazbuild_path= DEFAULT_LAZBUILD_PATH;
	std::string arg_strip_path	 = DEFAULT_STRIP_PATH;

	for (int i= 1; i < argc; ++i)
	{
		std::string a= argv[i];
		if (a == "-h" || a == "--help" || a == "/?")
		{
			PrintHelp(argv[0]);
			return 0;
		}
		else if (a == "-p" && i + 1 < argc)
			arg_catpaq_path= argv[++i];
		else if (a == "-l" && i + 1 < argc)
			arg_lazbuild_path= argv[++i];
		else if (a == "-s" && i + 1 < argc)
			arg_strip_path= argv[++i];
		else
		{
			std::cerr << "ERROR: Unknown argument: " << a << "\nUse -h for help.\n";
			return 1;
		}
	}

	catpaq_PATH	 = EnsureTrailingSlash(arg_catpaq_path);
	LAZBUILD_PATH= arg_lazbuild_path;
	STRIP_PATH	 = arg_strip_path;

	EXE_FILE	 = catpaq_PATH + "catpaq.exe";
	ZPAQFRANZ_EXE= catpaq_PATH + "zpaqfranz.exe";
	ZPAQFRANZ_DLL= catpaq_PATH + "zpaqfranz.dll";
	SOURCE_FILE	 = catpaq_PATH + "ufrmmain.pas";
	PROJECT_FILE = catpaq_PATH + "catpaq.lpi";

	std::cout << "catpaq Build Tool by Franco Corbelli\n\nConfiguration:\n";
	std::cout << "  catpaq path : " << catpaq_PATH << "\n";
	std::cout << "  lazbuild    : " << LAZBUILD_PATH << "\n";
	std::cout << "  strip       : " << STRIP_PATH << "\n\n";

	if (!PreFlightChecks())
		return 1;

	std::cout << "Step 1: Incrementing build number in catpaq.lpi...\n";
	int newBuild= IncrementLpiBuildNumber(PROJECT_FILE);
	if (newBuild == 0)
		return 1;

	std::cout << "\nStep 2: Computing SHA256 hashes...\n";
	std::string dllHash= ComputeSHA256(ZPAQFRANZ_DLL);
	if (dllHash.empty())
		return 1;
	std::cout << "  zpaqfranz.dll: " << dllHash << "\n";

	std::string exeHash= ComputeSHA256(ZPAQFRANZ_EXE);
	if (exeHash.empty())
		return 1;
	std::cout << "  zpaqfranz.exe: " << exeHash << "\n";

	std::cout << "\nStep 3: Injecting hashes into ufrmmain.pas...\n";
	if (!InjectHashesIntoSource(SOURCE_FILE, dllHash, exeHash))
		return 1;

	std::cout << "\nStep 4: Recompiling project...\n";
	std::string cmdLineBuild= "\"" + LAZBUILD_PATH + "\" \"" + PROJECT_FILE + "\"";
	if (!RunProcess(cmdLineBuild, catpaq_PATH, "lazbuild"))
		return 1;

	std::cout << "\nStep 5: Stripping executable...\n";
	std::string cmdLineStrip= "\"" + STRIP_PATH + "\" \"" + EXE_FILE + "\"";
	if (!RunProcess(cmdLineStrip, "", "strip"))
		return 1;

	std::cout << "\nStep 6: Creating " << OUTPUT_FILE << "...\n";
	std::string datetime_exe= GetFileDateTime(EXE_FILE);
	std::string hash_exe	= ComputeSHA256(EXE_FILE);
	long long	size_exe	= GetFileSizeBytes(EXE_FILE);

	std::string datetime_zpaqfranz_exe= GetFileDateTime(ZPAQFRANZ_EXE);
	long long	size_zpaqfranz_exe	  = GetFileSizeBytes(ZPAQFRANZ_EXE);

	std::string datetime_zpaqfranz_dll= GetFileDateTime(ZPAQFRANZ_DLL);
	long long	size_zpaqfranz_dll	  = GetFileSizeBytes(ZPAQFRANZ_DLL);

	if (datetime_exe.empty() || hash_exe.empty() || size_exe == 0 ||
		datetime_zpaqfranz_exe.empty() || size_zpaqfranz_exe == 0 ||
		datetime_zpaqfranz_dll.empty() || size_zpaqfranz_dll == 0)
	{
		std::cerr << "ERROR: Cannot gather file information for version.txt\n\n";
		return 1;
	}

	std::ofstream out(OUTPUT_FILE);
	if (!out)
		return 1;

	out << newBuild << "\n";
	out << datetime_exe << "\n"
		<< hash_exe << "\n"
		<< size_exe << "\n";
	out << datetime_zpaqfranz_exe << "\n"
		<< exeHash << "\n"
		<< size_zpaqfranz_exe << "\n";
	out << datetime_zpaqfranz_dll << "\n"
		<< dllHash << "\n"
		<< size_zpaqfranz_dll << "\n";
	out.close();

	std::cout << "  " << OUTPUT_FILE << " written.\n\n";

	std::cout << "BUILD COMPLETE\n";
	std::cout << "  catpaq.exe   : " << hash_exe << " (" << size_exe << " bytes)\n";
	std::cout << "  zpaqfranz.exe: " << exeHash << " (" << size_zpaqfranz_exe << " bytes)\n";
	std::cout << "  zpaqfranz.dll: " << dllHash << " (" << size_zpaqfranz_dll << " bytes)\n\n";

	std::cout << "Updated to build " << newBuild << "\n";

	return 0;
}
