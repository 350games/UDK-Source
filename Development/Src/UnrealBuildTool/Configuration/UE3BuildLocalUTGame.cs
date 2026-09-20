/**
 * Local UTGame target assembled from the native UTGame sources that are present
 * in this source snapshot. It intentionally does not depend on the missing
 * UDKBase or UTEditor projects.
 */

using System.Collections.Generic;

namespace UnrealBuildTool
{
	enum LocalUTGameTargetType
	{
		Runtime,
		ScriptCompiler,
		Editor,
	}

	class UE3BuildLocalUTGame : UE3BuildGame
	{
		private readonly LocalUTGameTargetType TargetType;

		private bool BuildsEditorCode
		{
			get { return TargetType != LocalUTGameTargetType.Runtime; }
		}

		public UE3BuildLocalUTGame()
			: this( LocalUTGameTargetType.Runtime )
		{
		}

		public UE3BuildLocalUTGame( LocalUTGameTargetType InTargetType )
		{
			TargetType = InTargetType;
			if( BuildsEditorCode )
			{
				// The script compiler and editor both need UnrealEd's native code. Keep optional
				// proprietary integrations off so this target remains reproducible from
				// the recovered source and restored wxWidgets dependency.
				UE3BuildConfiguration.bBuildEditor = true;
				UE3BuildConfiguration.bCompileLeanAndMeanUE3 = false;
				UE3BuildConfiguration.bAllowManagedCode = false;
				UE3BuildConfiguration.bAllowSteamworks = false;
				UE3BuildConfiguration.bAllowGameSpy = false;
				UE3BuildConfiguration.bAllowLive = false;
				UE3BuildConfiguration.bAllowGameCenter = false;
				UE3BuildConfiguration.bCompileFaceFX = false;
				UE3BuildConfiguration.bCompileFaceFXStudio = false;
				UE3BuildConfiguration.bCompileBink = false;
				UE3BuildConfiguration.bCompileSpeedTree = false;
				UE3BuildConfiguration.bCompileTrioviz = false;
				UE3BuildConfiguration.bCompileSimplygon = false;
				UE3BuildConfiguration.bCompileFBX = false;
				UE3BuildConfiguration.bCompilePerforce = false;
				UE3BuildConfiguration.bCompileRecast = false;
				UE3BuildConfiguration.bCompileWxWidgets = true;
			}
			else
			{
				// The regular runtime target intentionally has neither the retained
				// editor source nor the optional non-lean SDKs.
				UE3BuildConfiguration.bBuildEditor = false;
				UE3BuildConfiguration.bCompileLeanAndMeanUE3 = true;
			}
		}

		public string GetGameName()
		{
			return "UTGame";
		}

		public string GetSubPlatform()
		{
			switch( TargetType )
			{
				case LocalUTGameTargetType.ScriptCompiler:
					return "ScriptCompiler";
				case LocalUTGameTargetType.Editor:
					return "Editor";
				default:
					return "";
			}
		}

		public string GetDesiredOnlineSubsystem( CPPEnvironment CPPEnv, UnrealTargetPlatform Platform )
		{
			return "PC";
		}

		public bool ShouldCompileES2()
		{
			return false;
		}

		public bool ShouldCompilePhysXMobile()
		{
			return false;
		}

		public void GetGameSpecificGlobalEnvironment( CPPEnvironment GlobalEnvironment, UnrealTargetPlatform Platform )
		{
			// UE3's allocator provides the alignment these legacy render types require,
			// but current MSVC cannot infer it through the global allocation operators.
			GlobalEnvironment.AdditionalArguments += " /wd4316";
			if( BuildsEditorCode )
			{
				// Build the retained sources with the active toolchain instead of linking
				// their VC9/VC10 archives, whose C and C++ runtime ABI is incompatible.
				GlobalEnvironment.Definitions.Add( "WITH_SOURCE_BUILT_CONVEX_DECOMPOSITION=1" );
			}

			// The source snapshot is missing these optional SDKs.  Keep the target on
			// the engine's existing no-feature paths instead of substituting headers or
			// runtime DLLs that cannot provide the original build-time APIs.
			UE3BuildConfiguration.bCompileScaleform = false;
			GlobalEnvironment.Definitions.Add( "WITH_D3D11_RHI=0" );
			GlobalEnvironment.Definitions.Add( "WITH_D3D11_TESSELLATION=0" );
			GlobalEnvironment.Definitions.Add( "WITH_OPENGL_RHI=0" );
			GlobalEnvironment.Definitions.Add( "WITH_NVIDIA_STEREO=0" );
			GlobalEnvironment.Definitions.Add( "WITH_OGGVORBIS=0" );
			GlobalEnvironment.Definitions.Add( "WITH_LZO=0" );
			GlobalEnvironment.Definitions.Add( "WITH_OPEN_AUTOMATE=0" );
			GlobalEnvironment.Definitions.Add( "WITH_JPEG=0" );
			GlobalEnvironment.Definitions.Add( "WITH_AVIWRITER=0" );
			GlobalEnvironment.Definitions.Add( "WITH_WINTAB=0" );
			GlobalEnvironment.Definitions.Add( "WITH_LOCAL_UTGAME=1" );
			// The local runtime still uses WinDrv.WindowsClient, IpDrv and the PC
			// online subsystem.  UE3's generic lean mode otherwise turns networking
			// off and also removes WinDrv's native class registration, leaving the
			// configured viewport client impossible to construct at startup.
			GlobalEnvironment.Definitions.Add( "WITH_UE3_NETWORKING=1" );
			// The archived source does not contain the Intel TBB 3.0 SDK that the
			// original Win64 target selected.  Use UE3's portable ANSI allocator for
			// this recovered target only; normal Win64 targets retain TBB.
			GlobalEnvironment.Definitions.Add( "WITH_LOCAL_UTGAME_NO_TBB=1" );
			if( !BuildsEditorCode )
			{
				GlobalEnvironment.Definitions.Add( "WITH_LOCAL_UTGAME_STATIC_CRT=1" );
			}
			GlobalEnvironment.Definitions.Add( "WITH_MODERN_LIBPNG=1" );
			GlobalEnvironment.Definitions.Add( "WITH_MODERN_LIBPNG_ZLIB_HEADER=1" );
			GlobalEnvironment.Definitions.Add( "WITH_BUNDLED_D3DX39=1" );
			// First-run shader caches are required by the retained D3D9 renderer.
			// Keep this independent of the full non-lean compiler stack: the source
			// guards restore only SP_PCD3D_SM3, not D3D11 or OpenGL compilation.
			GlobalEnvironment.Definitions.Add( "WITH_LOCAL_UTGAME_D3D9_SHADER_COMPILER=1" );
			GlobalEnvironment.Definitions.Add( "WITH_MODERN_XAUDIO2=1" );
			GlobalEnvironment.SystemIncludePaths.Add( "../External/tinyXML" );
		}

		public void GetGameSpecificPlatformConfigurationEnvironment( CPPEnvironment GlobalEnvironment, LinkEnvironment FinalLinkEnvironment )
		{
			// This recovered target deliberately has no matching PhysX/APEX SDK in the
			// snapshot.  Compile the engine's existing no-physics paths instead of
			// treating runtime DLLs as a substitute for the required headers and libs.
			GlobalEnvironment.Definitions.Add( "WITH_NOVODEX=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_DESTRUCTIBLE=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_GRB=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_CLOTHING=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_PARTICLES=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_EMITTER=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_IOFX=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_BASIC_IOS=0" );
			GlobalEnvironment.Definitions.Add( "WITH_APEX_SHIPPING=0" );

			FinalLinkEnvironment.DelayLoadDLLs.Remove( "PhysXLoaderDEBUG.dll" );
			FinalLinkEnvironment.DelayLoadDLLs.Remove( "PhysXLoader.dll" );
			FinalLinkEnvironment.DelayLoadDLLs.Remove( "PhysXLoader64DEBUG.dll" );
			FinalLinkEnvironment.DelayLoadDLLs.Remove( "PhysXLoader64.dll" );

			// These SDK-backed features are compiled out above, so keep their absent
			// import libraries out of the final link environment as well.
			GlobalEnvironment.Definitions.Remove( "WITH_JPEG=1" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "DirectShowDEBUG.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "DirectShow.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "DirectShowDEBUGx64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "DirectShowx64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "lzopro.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "lzopro_64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libvorbis.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libvorbisfile.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libogg.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libvorbis_64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libvorbisfile_64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libogg_64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "nvapi.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "nvapi64.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "nvtess.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "nvtessd.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "libpng.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "zlib.lib" );

			if( BuildsEditorCode )
			{
				FinalLinkEnvironment.AdditionalLibraries.Remove( "nvTriStripD_64.lib" );
				FinalLinkEnvironment.AdditionalLibraries.Remove( "nvTriStripD.lib" );
				FinalLinkEnvironment.AdditionalLibraries.Remove( "nvTriStrip_64.lib" );
				FinalLinkEnvironment.AdditionalLibraries.Remove( "nvTriStrip.lib" );
				FinalLinkEnvironment.AdditionalLibraries.Remove( "KissFFT.lib" );
			}

			if( !BuildsEditorCode )
			{
				// The bundled zlib.lib was built against the VC80 dynamic CRT. Build its
				// retained source with the lean runtime target, then allow /MT(/MTd)'s
				// CRT libraries while rejecting every dynamic CRT default library.
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBC" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCMT" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCPMT" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCP" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCD" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCMTD" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCPMTD" );
				FinalLinkEnvironment.ExcludedLibraries.Remove( "LIBCPD" );
				if( !FinalLinkEnvironment.ExcludedLibraries.Contains( "MSVCRT" ) )
				{
					FinalLinkEnvironment.ExcludedLibraries.Add( "MSVCRT" );
				}
				if( !FinalLinkEnvironment.ExcludedLibraries.Contains( "MSVCPRT" ) )
				{
					FinalLinkEnvironment.ExcludedLibraries.Add( "MSVCPRT" );
				}
				if( !FinalLinkEnvironment.ExcludedLibraries.Contains( "MSVCRTD" ) )
				{
					FinalLinkEnvironment.ExcludedLibraries.Add( "MSVCRTD" );
				}
				if( !FinalLinkEnvironment.ExcludedLibraries.Contains( "MSVCPRTD" ) )
				{
					FinalLinkEnvironment.ExcludedLibraries.Add( "MSVCPRTD" );
				}
			}

			// Use the Windows SDK's XAudio2 2.9 import library with the matching
			// headers, rather than the incomplete legacy DirectX9 audio subset.
			FinalLinkEnvironment.AdditionalLibraries.Remove( "X3DAudio.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "xapobase.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Remove( "XAPOFX.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Add( "xaudio2.lib" );

			// The bundled DirectX 9 import library binds XInput 1.3, which is not a
			// Windows 10 system dependency.  This marker is resolved to the active
			// Windows SDK's XInput 1.4 import library by VCToolChain after vcvarsall
			// has populated the versioned SDK paths.
			FinalLinkEnvironment.AdditionalLibraries.Remove( "XInput.lib" );
			FinalLinkEnvironment.AdditionalLibraries.Add( "WindowsSDKXInput.lib" );

			// The restored in-process SM3 compiler uses the Windows SDK compiler,
			// rather than the bundled D3DX 9.39 implementation. The regular lean
			// target omits this library because it compiles this translation unit out.
			FinalLinkEnvironment.AdditionalLibraries.Add( "d3dcompiler.lib" );

			// The bundled x86 libPNG archive predates SafeSEH metadata.  This is
			// confined to the recovered legacy target; modern/default targets keep
			// the toolchain's /SAFESEH setting.
			if( FinalLinkEnvironment.TargetPlatform == CPPTargetPlatform.Win32 )
			{
				FinalLinkEnvironment.AdditionalArguments += " /SAFESEH:NO";
			}
		}

		public FileItem GetXEXConfigFile()
		{
			return null;
		}

		public void SetUpGameEnvironment( CPPEnvironment GameCPPEnvironment, LinkEnvironment FinalLinkEnvironment, List<UE3ProjectDesc> GameProjects )
		{
			GameProjects.Add( new UE3ProjectDesc( "../External/wxWindows_2.4.0/src/zlib/zlib.Local.vcxproj" ) );
			GameProjects.Add( new UE3ProjectDesc( "../External/libPNG/libPNG.Local.vcxproj" ) );
			GameProjects.Add( new UE3ProjectDesc( "../External/tinyXML/tinyXML.Local.vcxproj" ) );
			if( BuildsEditorCode )
			{
				UE3ProjectDesc ConvexDecompositionProject = new UE3ProjectDesc( "../External/ConvexDecomposition/ConvexDecomposition.Local.vcxproj" );
				ConvexDecompositionProject.bDisableUnity = true;
				ConvexDecompositionProject.bDisablePCH = true;
				ConvexDecompositionProject.AdditionalCompilerArguments = " /D_CRT_SECURE_NO_WARNINGS=1 /wd4100 /wd4121 /wd4189 /wd4213 /wd4244 /wd4267 /wd4477 /wd4505 /wd4996";
				GameProjects.Add( ConvexDecompositionProject );
				UE3ProjectDesc NvTriStripProject = new UE3ProjectDesc( "../External/nvTriStrip/nvTriStrip.Local.vcxproj" );
				NvTriStripProject.AdditionalCompilerArguments = " /wd4100 /wd4189 /wd4267 /wd4389";
				GameProjects.Add( NvTriStripProject );
				GameProjects.Add( new UE3ProjectDesc( "../External/kiss_fft129/KissFFT.Local.vcxproj" ) );
				GameCPPEnvironment.IncludePaths.Add( "../External/ConvexDecomposition/ConvexDecomposition" );
				GameCPPEnvironment.IncludePaths.Add( "../External/nvTriStrip/Inc" );
				GameCPPEnvironment.IncludePaths.Add( "../External/nvTriStrip/Src" );
				GameCPPEnvironment.IncludePaths.Add( "../External/kiss_fft129" );
			}
			GameProjects.Add( new UE3ProjectDesc( "UTGame/UTGame.vcxproj" ) );
			GameCPPEnvironment.IncludePaths.Add( "UTGame/Inc" );
			GameCPPEnvironment.Definitions.Add( "GAMENAME=UTGAME" );
			GameCPPEnvironment.Definitions.Add( "IS_UTGAME=1" );
			GameCPPEnvironment.Definitions.Add( "SUPPORTS_TILT_PUSHER=1" );
			GameCPPEnvironment.Definitions.Add( "WITH_HASH_FILE=0" );
		}
	}
}
