using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

namespace UE3Workbench
{
	internal sealed class ProjectSettingsData
	{
		public string StartupMap;
		public string ProjectDisplayName;
		public string RendererIntent;
		public string ShaderModelIntent;
		public bool RequestHdr;
		public bool RequestThreadedRenderer;
		public bool AllowOpenGl;
		public bool AllowHighQualityMaterials;
		public bool AllowPostprocessMlAa;
		public bool UseVsync;
		public bool EnableLocalPlugins;
		public bool AllowUnsignedPlugins;
		public bool KeepBuildLogs;
		public bool KeepStartupDiagnostics;
		public bool WarnExperimentalRenderer;
	}

	/// <summary>
	/// Reads and writes the settings that genuinely belong to this UTGame project.
	/// Future renderer and plugin choices are recorded as Workbench intent only;
	/// they are never presented as active engine backends before one exists.
	/// </summary>
	internal sealed class ProjectSettingsStore
	{
		private const string UrlSection = "URL";
		private const string SystemSettingsSection = "SystemSettings";
		private const string WorkbenchSection = "UE3Workbench.Project";

		private readonly string workspaceRoot;
		private readonly string mapsDirectory;
		private readonly IniFileStore defaultEngineSettings;
		private readonly IniFileStore runtimeEngineSettings;
		private readonly IniFileStore runtimeSystemSettings;
		private readonly IniFileStore workbenchSettings;

		public ProjectSettingsStore( string workspaceRoot )
		{
			this.workspaceRoot = workspaceRoot;
			mapsDirectory = Path.Combine( workspaceRoot, "UTGame", "Content", "Maps" );
			string configDirectory = Path.Combine( workspaceRoot, "UTGame", "Config" );
			defaultEngineSettings = new IniFileStore( Path.Combine( configDirectory, "DefaultEngine.ini" ) );
			runtimeEngineSettings = new IniFileStore( Path.Combine( configDirectory, "UTEngine.ini" ) );
			runtimeSystemSettings = new IniFileStore( Path.Combine( configDirectory, "UTSystemSettings.ini" ) );
			workbenchSettings = new IniFileStore( Path.Combine( configDirectory, "UE3Workbench.ini" ) );
		}

		public ProjectSettingsData Load()
		{
			ProjectSettingsData settings = new ProjectSettingsData();
			settings.StartupMap = defaultEngineSettings.GetValue( UrlSection, "Map", "ExampleEntry.udk" );
			settings.ProjectDisplayName = workbenchSettings.GetValue( WorkbenchSection, "ProjectDisplayName", "UTGame" );
			settings.RendererIntent = workbenchSettings.GetValue( WorkbenchSection, "RendererIntent", "D3D9" );
			settings.ShaderModelIntent = workbenchSettings.GetValue( WorkbenchSection, "ShaderModelIntent", "SM3" );
			settings.RequestHdr = GetBool( workbenchSettings, WorkbenchSection, "RequestHdr", false );
			settings.RequestThreadedRenderer = GetBool( workbenchSettings, WorkbenchSection, "RequestThreadedRenderer", false );
			settings.AllowOpenGl = GetBool( runtimeSystemSettings, SystemSettingsSection, "AllowOpenGL", false );
			settings.AllowHighQualityMaterials = GetBool( runtimeSystemSettings, SystemSettingsSection, "bAllowHighQualityMaterials", true );
			settings.AllowPostprocessMlAa = GetBool( runtimeSystemSettings, SystemSettingsSection, "bAllowPostprocessMLAA", false );
			settings.UseVsync = GetBool( runtimeSystemSettings, SystemSettingsSection, "UseVsync", false );
			settings.EnableLocalPlugins = GetBool( workbenchSettings, WorkbenchSection, "EnableLocalPlugins", false );
			settings.AllowUnsignedPlugins = GetBool( workbenchSettings, WorkbenchSection, "AllowUnsignedPlugins", false );
			settings.KeepBuildLogs = GetBool( workbenchSettings, WorkbenchSection, "KeepBuildLogs", false );
			settings.KeepStartupDiagnostics = GetBool( workbenchSettings, WorkbenchSection, "KeepStartupDiagnostics", false );
			settings.WarnExperimentalRenderer = GetBool( workbenchSettings, WorkbenchSection, "WarnExperimentalRenderer", true );
			return settings;
		}

		public IList<string> GetAvailableMaps()
		{
			List<string> maps = new List<string>();
			if( !Directory.Exists( mapsDirectory ) )
			{
				return maps;
			}

			foreach( string filePath in Directory.GetFiles( mapsDirectory, "*.udk", SearchOption.AllDirectories ) )
			{
				string relativePath = filePath.Substring( mapsDirectory.Length ).TrimStart( Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar );
				maps.Add( relativePath );
			}
			maps.Sort( StringComparer.OrdinalIgnoreCase );
			return maps;
		}

		public void Save( ProjectSettingsData settings )
		{
			string startupMap = ValidateStartupMap( settings.StartupMap );
			string displayName = String.IsNullOrWhiteSpace( settings.ProjectDisplayName ) ? "UTGame" : settings.ProjectDisplayName.Trim();
			if( displayName.IndexOfAny( new[] { '\r', '\n' } ) >= 0 )
			{
				throw new InvalidOperationException( "Project display name cannot contain a new line." );
			}

			KeyValuePair<string, string>[] urlValues = new[]
			{
				new KeyValuePair<string, string>( "Map", startupMap ),
				new KeyValuePair<string, string>( "LocalMap", startupMap )
			};
			defaultEngineSettings.SetValues( UrlSection, urlValues );
			runtimeEngineSettings.SetValues( UrlSection, urlValues );

			runtimeSystemSettings.SetValues(
				SystemSettingsSection,
				new[]
				{
					new KeyValuePair<string, string>( "AllowOpenGL", ToIniBool( settings.AllowOpenGl ) ),
					new KeyValuePair<string, string>( "bAllowHighQualityMaterials", ToIniBool( settings.AllowHighQualityMaterials ) ),
					new KeyValuePair<string, string>( "bAllowPostprocessMLAA", ToIniBool( settings.AllowPostprocessMlAa ) ),
					new KeyValuePair<string, string>( "UseVsync", ToIniBool( settings.UseVsync ) )
				} );

			workbenchSettings.SetValues(
				WorkbenchSection,
				new[]
				{
					new KeyValuePair<string, string>( "ProjectDisplayName", displayName ),
					new KeyValuePair<string, string>( "RendererIntent", settings.RendererIntent ?? "D3D9" ),
					new KeyValuePair<string, string>( "ShaderModelIntent", settings.ShaderModelIntent ?? "SM3" ),
					new KeyValuePair<string, string>( "RequestHdr", ToIniBool( settings.RequestHdr ) ),
					new KeyValuePair<string, string>( "RequestThreadedRenderer", ToIniBool( settings.RequestThreadedRenderer ) ),
					new KeyValuePair<string, string>( "EnableLocalPlugins", ToIniBool( settings.EnableLocalPlugins ) ),
					new KeyValuePair<string, string>( "AllowUnsignedPlugins", ToIniBool( settings.AllowUnsignedPlugins ) ),
					new KeyValuePair<string, string>( "KeepBuildLogs", ToIniBool( settings.KeepBuildLogs ) ),
					new KeyValuePair<string, string>( "KeepStartupDiagnostics", ToIniBool( settings.KeepStartupDiagnostics ) ),
					new KeyValuePair<string, string>( "WarnExperimentalRenderer", ToIniBool( settings.WarnExperimentalRenderer ) )
				} );
		}

		private string ValidateStartupMap( string startupMap )
		{
			if( String.IsNullOrWhiteSpace( startupMap ) )
			{
				throw new InvalidOperationException( "Choose a startup map from UTGame\\Content\\Maps." );
			}

			string normalized = startupMap.Trim().Replace( Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar );
			if( Path.IsPathRooted( normalized ) || normalized.IndexOf( "..", StringComparison.Ordinal ) >= 0 ||
				!String.Equals( Path.GetExtension( normalized ), ".udk", StringComparison.OrdinalIgnoreCase ) )
			{
				throw new InvalidOperationException( "The startup map must be a .udk file inside UTGame\\Content\\Maps." );
			}

			string candidate = Path.Combine( mapsDirectory, normalized );
			if( !File.Exists( candidate ) )
			{
				throw new InvalidOperationException( "The selected startup map was not found: " + normalized );
			}

			return normalized.Replace( Path.DirectorySeparatorChar, '/' );
		}

		private static bool GetBool( IniFileStore store, string section, string key, bool fallback )
		{
			string rawValue = store.GetValue( section, key, fallback ? "True" : "False" );
			bool parsed;
			if( Boolean.TryParse( rawValue, out parsed ) )
			{
				return parsed;
			}
			int numeric;
			if( Int32.TryParse( rawValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out numeric ) )
			{
				return numeric != 0;
			}
			return fallback;
		}

		private static string ToIniBool( bool value )
		{
			return value ? "True" : "False";
		}
	}
}
