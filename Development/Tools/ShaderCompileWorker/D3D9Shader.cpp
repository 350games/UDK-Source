/**
 * Copyright 1998-2013 Epic Games, Inc. All Rights Reserved.
 */

#include "ShaderCompileWorker.h"
#if WITH_LOCAL_UTGAME_WORKER
#include <d3dcompiler.h>
#else
#include <d3d9.h>
#include <d3dx9.h>
#endif

const BYTE D3D9ShaderCompileWorkerInputVersion = 0;
const BYTE D3D9ShaderCompileWorkerOutputVersion = 1;
#if !WITH_LOCAL_UTGAME_WORKER
const UINT REQUIRED_D3DX9_SDK_VERSION = 43;
#endif

#if WITH_LOCAL_UTGAME_WORKER
typedef D3D_SHADER_MACRO FD3D9ShaderMacro;
typedef ID3DInclude FD3D9Include;
typedef ID3DBlob FD3D9ShaderBlob;
#else
typedef D3DXMACRO FD3D9ShaderMacro;
typedef ID3DXInclude FD3D9Include;
typedef ID3DXBuffer FD3D9ShaderBlob;
#endif

/**
 * An implementation of the shader compiler include interface.
 */
class FD3D9IncludeEnvironment : public FD3D9Include
{
public:
	vector<FInclude> Includes;

#if WITH_LOCAL_UTGAME_WORKER
	STDMETHOD(Open)(D3D_INCLUDE_TYPE Type,LPCSTR Name,LPCVOID ParentData,LPCVOID* Data,UINT* Bytes)
#else
	STDMETHOD(Open)(D3DXINCLUDE_TYPE Type,LPCSTR Name,LPCVOID ParentData,LPCVOID* Data,UINT* Bytes)
#endif
	{
		bool bFoundInclude = false;
		for (UINT IncludeIndex = 0; IncludeIndex < Includes.size(); IncludeIndex++)
		{
			if (Includes[IncludeIndex].IncludeName == Name)
			{
				bFoundInclude = true;
				const UINT DataLength = ( UINT )Includes[IncludeIndex].IncludeFile.size();
				CHAR* OutData = new CHAR[DataLength];
				memcpy(OutData, Includes[IncludeIndex].IncludeFile.c_str(), DataLength);
				*Data = OutData;
				*Bytes = DataLength;
				break;
			}
		}

		if (!bFoundInclude)
		{
			BYTE* FileContents = NULL;
			UINT FileSize = 0;
			bFoundInclude = LoadShaderSourceFile( IncludePath, Name, &FileContents, &FileSize );
			if ( bFoundInclude )
			{
				*Data = FileContents;
				*Bytes = FileSize;
			}
		}

		return bFoundInclude ? S_OK : S_FALSE;
	}

	STDMETHOD(Close)(LPCVOID Data)
	{
		delete [] Data;
		return S_OK;
	}


	FD3D9IncludeEnvironment(const string& InIncludePath) :
		IncludePath(InIncludePath)
	{}


private:

	string IncludePath;
};

/**
 * This wraps the shader compiler in a __try __except block to catch occasional crashes in the function.
 */
static HRESULT D3D9SafeCompileShader(
	LPCSTR pSrcData,
	UINT srcDataLen,
	FD3D9ShaderMacro* Macros,
	FD3D9Include* pInclude,
	LPCSTR pFunctionName,
	LPCSTR pProfile,
	DWORD Flags,
	FD3D9ShaderBlob** ppShader,
	FD3D9ShaderBlob** ppErrorMsgs
	)
{
	__try
	{
#if WITH_LOCAL_UTGAME_WORKER
		// D3DX's D3D9 compiler flags deliberately mirror D3DCompile's flags.
		// The one exception is the obsolete D3DX 9.31 fallback bit, which has no
		// meaning for D3DCompile and would be interpreted as a reserved flag.
		return D3DCompile(
			pSrcData,
			srcDataLen,
			"memory",
			Macros,
			pInclude,
			pFunctionName,
			pProfile,
			Flags & ~(1 << 16),
			0,
			ppShader,
			ppErrorMsgs
			);
#else
		return D3DXCompileShader(
			pSrcData,
			srcDataLen,			
			Macros,
			pInclude,
			pFunctionName,
			pProfile,
			Flags,
			ppShader,
			ppErrorMsgs,
			NULL
			);
#endif
	}
	__except(EXCEPTION_EXECUTE_HANDLER)
	{
#if WITH_LOCAL_UTGAME_WORKER
		ERRORF(TEXT("D3DCompile threw an exception"));
		return E_FAIL;
#else
		Log(TEXT("D3DXCompileShader threw an exception, trying the legacy compiler"));
		for (INT i = 0; Macros[i].Name != NULL; i++)
		{
			if (strcmp(Macros[i].Name, "COMPILER_SUPPORTS_ATTRIBUTES") == 0)
			{
				delete [] Macros[i].Definition;
				Macros[i].Definition = _strdup("0");
			}
		}

		__try
		{
			return D3DXCompileShader(
				pSrcData,
				srcDataLen,			
				Macros,
				pInclude,
				pFunctionName,
				pProfile,
				Flags | D3DXSHADER_USE_LEGACY_D3DX9_31_DLL,
				ppShader,
				ppErrorMsgs,
				NULL
				);
		}
		__except(EXCEPTION_EXECUTE_HANDLER)
		{
			ERRORF(TEXT("D3DXCompileShader threw an exception with the legacy compiler!"));
			return E_FAIL;
		}
#endif
	}
}

/** Wraps the shader disassembler in a __try __except block to catch unpredictable crashes in the function. */
static HRESULT D3D9SafeDisassembleShader(
	CONST DWORD * pShader,
	UINT ShaderByteCodeLength,
	BOOL EnableColorCode,
	LPCSTR pComments,
	FD3D9ShaderBlob** ppDisassembly
	)
{
	__try
	{
	#if WITH_LOCAL_UTGAME_WORKER
		return D3DDisassemble(pShader, ShaderByteCodeLength, EnableColorCode ? D3D_DISASM_ENABLE_COLOR_CODE : 0, pComments, ppDisassembly);
	#else
		return D3DXDisassembleShader(pShader, EnableColorCode, pComments, ppDisassembly);
	#endif
	}
	__except(EXCEPTION_EXECUTE_HANDLER)
	{
		ERRORF( TEXT("Caught exception from the shader disassembler"));
		return -1;
	}
}

#if !WITH_LOCAL_UTGAME_WORKER
/** Wraps GetConstantDesc in a __try __except block to catch unpredictable crashes in the function. */
static HRESULT D3D9SafeGetConstantDesc(
	ID3DXConstantTable* ConstantTable,
	D3DXHANDLE ConstantHandle,
	D3DXCONSTANT_DESC* ConstantDesc,
	UINT* NumConstants
	)
{
	__try
	{
		return ConstantTable->GetConstantDesc(ConstantHandle,ConstantDesc,NumConstants);
	}
	__except(EXCEPTION_EXECUTE_HANDLER)
	{
		ERRORF( TEXT("Caught exception from ConstantTable->GetConstantDesc()"));
		return -1;
	}
}
#endif

/** Information about a constant passed back from the worker application. */
struct FD3D9ConstantDesc
{
	enum { MaxNameLength = 256 };

	char Name[MaxNameLength];
	BOOL bIsSampler;
	UINT RegisterIndex;
	UINT RegisterCount;
};

#if WITH_LOCAL_UTGAME_WORKER
/**
 * D3DCompile emits valid D3D9 bytecode, but D3DReflect intentionally does
 * not support Shader Model 3 bytecode. D3DDisassemble still includes the
 * D3D9 constant register table, which is exactly the information the engine
 * serializes from ID3DXConstantTable in the original worker.
 */
static void D3D9ExtractConstantsFromDisassembly(const char* Disassembly, vector<FD3D9ConstantDesc>& Constants)
{
	const char* RegisterTable = strstr(Disassembly, "//   ------------");
	if (RegisterTable == NULL)
	{
		return;
	}

	const char* Cursor = strchr(RegisterTable, '\n');
	while (Cursor != NULL)
	{
		++Cursor;
		if (Cursor[0] != '/' || Cursor[1] != '/')
		{
			break;
		}

		const char* LineEnd = strchr(Cursor, '\n');
		const size_t LineLength = LineEnd ? (size_t)(LineEnd - Cursor) : strlen(Cursor);
		char Line[512];
		const size_t CopyLength = LineLength < sizeof(Line) - 1 ? LineLength : sizeof(Line) - 1;
		memcpy(Line, Cursor, CopyLength);
		Line[CopyLength] = 0;

		char Name[FD3D9ConstantDesc::MaxNameLength];
		char Register[32];
		UINT RegisterCount = 0;
		if (sscanf_s(Line, "// %255s %31s %u", Name, (unsigned)_countof(Name), Register, (unsigned)_countof(Register), &RegisterCount) == 3)
		{
			const char* RegisterIndexText = Register + 1;
			if ((Register[0] == 'c' || Register[0] == 's' || Register[0] == 'i' || Register[0] == 'b') && *RegisterIndexText >= '0' && *RegisterIndexText <= '9')
			{
				FD3D9ConstantDesc Constant;
				strncpy_s(Constant.Name, _countof(Constant.Name), Name, _TRUNCATE);
				Constant.bIsSampler = Register[0] == 's';
				Constant.RegisterIndex = (UINT)strtoul(RegisterIndexText, NULL, 10);
				Constant.RegisterCount = RegisterCount;
				Constants.push_back(Constant);
			}
		}

		if (LineEnd == NULL)
		{
			break;
		}
		Cursor = LineEnd;
	}
}
#endif

bool D3D9CompileShader(BYTE InputVersion, const vector<BYTE>& WorkerInput, UINT& Offset, vector<BYTE>& OutputData)
{
	CHECKF(InputVersion == D3D9ShaderCompileWorkerInputVersion, TEXT("Wrong job version for D3D9 shader"));
	#if !WITH_LOCAL_UTGAME_WORKER
	CHECKF(D3DX_SDK_VERSION == REQUIRED_D3DX9_SDK_VERSION, TEXT("Compiled with wrong DX SDK, June 2010 DX SDK required"));
	#endif

	// Read the input from UE3
	string SourceFile;
	ParseAnsiString(WorkerInput, Offset, SourceFile);

	string FunctionName;
	ParseAnsiString(WorkerInput, Offset, FunctionName);

	string ShaderProfile;
	ParseAnsiString(WorkerInput, Offset, ShaderProfile);

	DWORD CompileFlags;
	ReadValue(WorkerInput, Offset, CompileFlags);

	string IncludePath;
	ParseAnsiString(WorkerInput, Offset, IncludePath);
	FD3D9IncludeEnvironment IncludeEnvironment(IncludePath);

	UINT NumIncludes;
	ReadValue(WorkerInput, Offset, NumIncludes);

	for (UINT IncludeIndex = 0; IncludeIndex < NumIncludes; IncludeIndex++)
	{
		FInclude NewInclude;
		ParseAnsiString(WorkerInput, Offset, NewInclude.IncludeName);
		ParseAnsiString(WorkerInput, Offset, NewInclude.IncludeFile);
		IncludeEnvironment.Includes.push_back(NewInclude);
	}

	UINT NumMacros;
	ReadValue(WorkerInput, Offset, NumMacros);

	vector<FD3D9ShaderMacro> Macros;
	for (UINT MacroIndex = 0; MacroIndex < NumMacros; MacroIndex++)
	{
		FD3D9ShaderMacro NewMacro;
		UINT NameLen;
		ParseAnsiString(WorkerInput, Offset, NewMacro.Name, NameLen);
		UINT DefinitionLen;
		ParseAnsiString(WorkerInput, Offset, NewMacro.Definition, DefinitionLen);
		Macros.push_back(NewMacro);
	}

	FD3D9ShaderMacro TerminatorMacro;
	TerminatorMacro.Name = NULL;
	TerminatorMacro.Definition = NULL;
	Macros.push_back(TerminatorMacro);

	FD3D9ShaderBlob* ShaderByteCode = NULL;
	FD3D9ShaderBlob* Errors = NULL;

	// Compile the shader through the selected local or legacy compiler.
	HRESULT hr = D3D9SafeCompileShader(
		SourceFile.c_str(),
		(UINT)SourceFile.size(),
		&Macros.front(),
		&IncludeEnvironment,
		FunctionName.c_str(),
		ShaderProfile.c_str(),
		CompileFlags,
		&ShaderByteCode,
		&Errors
		);

	for (UINT MacroIndex = 0; MacroIndex < Macros.size(); MacroIndex++)
	{
		delete [] Macros[MacroIndex].Name;
		delete [] Macros[MacroIndex].Definition;
	}

	vector<FD3D9ConstantDesc> Constants;
	FD3D9ShaderBlob* DisassemblyBuffer = NULL;
	if(SUCCEEDED(hr))
	{
		// Disassemble the shader to determine the instruction count. The local
		// compiler also exposes the D3D9 register table through this text.
		VERIFYF(SUCCEEDED(D3D9SafeDisassembleShader((const DWORD*)ShaderByteCode->GetBufferPointer(), (UINT)ShaderByteCode->GetBufferSize(), FALSE, NULL, &DisassemblyBuffer)), TEXT("Failed to disassemble shader bytecode."));

		#if WITH_LOCAL_UTGAME_WORKER
		D3D9ExtractConstantsFromDisassembly((const char*)DisassemblyBuffer->GetBufferPointer(), Constants);
		#else
		// Read the constant table output from the shader bytecode.
		ID3DXConstantTable* ConstantTable = NULL;
		VERIFYF(SUCCEEDED(D3DXGetShaderConstantTable((DWORD*)ShaderByteCode->GetBufferPointer(), &ConstantTable)), TEXT("Failed to read shader constant table.") );
		D3DXCONSTANTTABLE_DESC ConstantTableDesc;
		VERIFYF(SUCCEEDED(ConstantTable->GetDesc(&ConstantTableDesc)), TEXT("Failed to describe shader constant table."));

		// Read the constant descriptions out of the shader bytecode.
		for(UINT ConstantIndex = 0;ConstantIndex < ConstantTableDesc.Constants;ConstantIndex++)
		{
			// Read the constant description.
			D3DXHANDLE ConstantHandle = ConstantTable->GetConstant(NULL,ConstantIndex);
			D3DXCONSTANT_DESC ConstantDesc;
			UINT NumConstants = 1;
			VERIFYF(SUCCEEDED(D3D9SafeGetConstantDesc(ConstantTable, ConstantHandle, &ConstantDesc, &NumConstants)), TEXT("Failed to describe shader constant."));

			// Copy the constant and its name into a self-contained data structure, and add it to the constant array.
			FD3D9ConstantDesc NamedConstantDesc;
			const UINT NameLength = (UINT)strlen(ConstantDesc.Name);
			//@todo - actually log constant name
			CHECKF(NameLength < FD3D9ConstantDesc::MaxNameLength, TEXT("Constant Name too long!"));
			strncpy_s(NamedConstantDesc.Name,FD3D9ConstantDesc::MaxNameLength,ConstantDesc.Name,_TRUNCATE);
			NamedConstantDesc.bIsSampler = ConstantDesc.RegisterSet == D3DXRS_SAMPLER;
			NamedConstantDesc.RegisterCount = ConstantDesc.RegisterCount;
			NamedConstantDesc.RegisterIndex = ConstantDesc.RegisterIndex;
			Constants.push_back(NamedConstantDesc);
		}

		// Release the constant table.
		ConstantTable->Release();
		#endif
	}

	const EWorkerJobType JobType = WJT_D3D9Shader;
	const UINT ByteCodeLength = SUCCEEDED(hr) ? (UINT)ShaderByteCode->GetBufferSize() : 0;
	const UINT ErrorStringLength = Errors == NULL ? 0 : (UINT)Errors->GetBufferSize();
	const UINT ConstantArrayLength = (UINT)(Constants.size() * sizeof(FD3D9ConstantDesc));
	const UINT DisassemblyLength = DisassemblyBuffer ? (UINT)DisassemblyBuffer->GetBufferSize() : 0;

	// Write the output for UE3
	WriteValue(OutputData, D3D9ShaderCompileWorkerOutputVersion);
	WriteValue(OutputData, JobType);
	WriteValue(OutputData, hr);
	WriteValue(OutputData, ByteCodeLength);
	if (ByteCodeLength > 0)
	{
		WriteArray(OutputData, ShaderByteCode->GetBufferPointer(), ByteCodeLength);
	}
	WriteValue(OutputData, ErrorStringLength);
	if (ErrorStringLength > 0)
	{
		WriteArray(OutputData, Errors->GetBufferPointer(), ErrorStringLength);
	}

	WriteValue(OutputData, ConstantArrayLength );
	if(ConstantArrayLength > 0)
	{
		WriteArray(OutputData, &Constants[0], ConstantArrayLength );
	}

	WriteValue(OutputData, DisassemblyLength );
	if(DisassemblyLength > 0)
	{
		WriteArray(OutputData,DisassemblyBuffer->GetBufferPointer(),DisassemblyLength);
	}

	// Cleanup
	if (ShaderByteCode != NULL)
	{
		ShaderByteCode->Release();
	}

	if (Errors != NULL)
	{
		Errors->Release();
	}

	if(DisassemblyBuffer)
	{
		DisassemblyBuffer->Release();
	}

	return true;
}
