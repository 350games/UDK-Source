using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;

namespace UE3Workbench
{
	internal sealed class EditorUserSettingsData
	{
		public bool LoadSimpleLevelAtStartup;
		public bool EnableRealTimeAudio;
		public decimal EditorVolumeLevel;
		public string FlightCameraControlType;
		public bool StartInRealtimeMode;
		public bool UseLinkedOrthographicViewports;
		public bool EnableShowFlagsShortcut;
		public bool EnableViewportHoverFeedback;
		public bool EnableViewportCameraToUpdateFromPiv;
		public bool AutoSaveEnabled;
		public bool AutoSaveMaps;
		public bool AutoSaveContent;
		public int AutoSaveTimeMinutes;
		public int UndoBufferSize;
		public bool PromptForCheckout;
		public bool SourceControlEnabled;
		public bool AutoAddNewFiles;
	}

	/// <summary>
	/// Updates a focused set of existing UnrealEd user preferences while preserving
	/// every unrelated entry in UTEditorUserSettings.ini.
	/// </summary>
	internal sealed class EditorUserSettingsStore
	{
		private const string EditorSection = "UnrealEd.EditorUserSettings";
		private const string UndoSection = "Undo";
		private const string SourceControlSection = "SourceControl";

		private readonly IniFileStore settingsFile;

		public EditorUserSettingsStore( string workspaceRoot )
		{
			settingsFile = new IniFileStore( Path.Combine( workspaceRoot, "UTGame", "Config", "UTEditorUserSettings.ini" ) );
		}

		public EditorUserSettingsData Load()
		{
			EditorUserSettingsData settings = new EditorUserSettingsData();
			settings.LoadSimpleLevelAtStartup = GetBool( EditorSection, "bLoadSimpleLevelAtStartup", true );
			settings.EnableRealTimeAudio = GetBool( EditorSection, "bEnableRealTimeAudio", false );
			settings.EditorVolumeLevel = GetDecimal( EditorSection, "EditorVolumeLevel", 1.0m, 0.0m, 1.0m );
			settings.FlightCameraControlType = GetFlightCameraControlType();
			settings.StartInRealtimeMode = GetBool( EditorSection, "bStartInRealtimeMode", true );
			settings.UseLinkedOrthographicViewports = GetBool( EditorSection, "bUseLinkedOrthographicViewports", true );
			settings.EnableShowFlagsShortcut = GetBool( EditorSection, "bEnableShowFlagsShortcut", false );
			settings.EnableViewportHoverFeedback = GetBool( EditorSection, "bEnableViewportHoverFeedback", false );
			settings.EnableViewportCameraToUpdateFromPiv = GetBool( EditorSection, "bEnableViewportCameraToUpdateFromPIV", true );
			settings.AutoSaveEnabled = GetBool( EditorSection, "bAutoSaveEnable", true );
			settings.AutoSaveMaps = GetBool( EditorSection, "bAutoSaveMaps", true );
			settings.AutoSaveContent = GetBool( EditorSection, "bAutoSaveContent", true );
			settings.AutoSaveTimeMinutes = GetInt( EditorSection, "AutoSaveTimeMinutes", 10, 1, 30 );
			settings.UndoBufferSize = GetInt( UndoSection, "UndoBufferSize", 16, 1, 256 );
			settings.PromptForCheckout = GetBool( EditorSection, "bPromptForCheckoutOnPackageModification", true );
			settings.SourceControlEnabled = !GetBool( SourceControlSection, "Disabled", true );
			settings.AutoAddNewFiles = GetBool( SourceControlSection, "AutoAddNewFiles", true );
			return settings;
		}

		public void Save( EditorUserSettingsData settings )
		{
			Validate( settings );

			settingsFile.SetValues(
				EditorSection,
				new[]
				{
					new KeyValuePair<string, string>( "bLoadSimpleLevelAtStartup", ToIniBool( settings.LoadSimpleLevelAtStartup ) ),
					new KeyValuePair<string, string>( "bEnableRealTimeAudio", ToIniBool( settings.EnableRealTimeAudio ) ),
					new KeyValuePair<string, string>( "EditorVolumeLevel", settings.EditorVolumeLevel.ToString( "0.000000", CultureInfo.InvariantCulture ) ),
					new KeyValuePair<string, string>( "FlightCameraControlType", settings.FlightCameraControlType ),
					new KeyValuePair<string, string>( "bStartInRealtimeMode", ToIniBool( settings.StartInRealtimeMode ) ),
					new KeyValuePair<string, string>( "bUseLinkedOrthographicViewports", ToIniBool( settings.UseLinkedOrthographicViewports ) ),
					new KeyValuePair<string, string>( "bEnableShowFlagsShortcut", ToIniBool( settings.EnableShowFlagsShortcut ) ),
					new KeyValuePair<string, string>( "bEnableViewportHoverFeedback", ToIniBool( settings.EnableViewportHoverFeedback ) ),
					new KeyValuePair<string, string>( "bEnableViewportCameraToUpdateFromPIV", ToIniBool( settings.EnableViewportCameraToUpdateFromPiv ) ),
					new KeyValuePair<string, string>( "bAutoSaveEnable", ToIniBool( settings.AutoSaveEnabled ) ),
					new KeyValuePair<string, string>( "bAutoSaveMaps", ToIniBool( settings.AutoSaveMaps ) ),
					new KeyValuePair<string, string>( "bAutoSaveContent", ToIniBool( settings.AutoSaveContent ) ),
					new KeyValuePair<string, string>( "AutoSaveTimeMinutes", settings.AutoSaveTimeMinutes.ToString( CultureInfo.InvariantCulture ) ),
					new KeyValuePair<string, string>( "bPromptForCheckoutOnPackageModification", ToIniBool( settings.PromptForCheckout ) )
				} );

			settingsFile.SetValues(
				UndoSection,
				new[] { new KeyValuePair<string, string>( "UndoBufferSize", settings.UndoBufferSize.ToString( CultureInfo.InvariantCulture ) ) } );

			settingsFile.SetValues(
				SourceControlSection,
				new[]
				{
					new KeyValuePair<string, string>( "Disabled", ToIniBool( !settings.SourceControlEnabled ) ),
					new KeyValuePair<string, string>( "AutoAddNewFiles", ToIniBool( settings.AutoAddNewFiles ) )
				} );
		}

		private void Validate( EditorUserSettingsData settings )
		{
			if( settings.EditorVolumeLevel < 0.0m || settings.EditorVolumeLevel > 1.0m )
			{
				throw new InvalidOperationException( "Editor volume must be between 0 and 1." );
			}
			if( settings.AutoSaveTimeMinutes != 1 && settings.AutoSaveTimeMinutes != 5 && settings.AutoSaveTimeMinutes != 10 &&
				settings.AutoSaveTimeMinutes != 15 && settings.AutoSaveTimeMinutes != 30 )
			{
				throw new InvalidOperationException( "Autosave interval must be 1, 5, 10, 15, or 30 minutes." );
			}
			if( settings.UndoBufferSize < 1 || settings.UndoBufferSize > 256 )
			{
				throw new InvalidOperationException( "Undo buffer size must be between 1 and 256 MB." );
			}
			if( !String.Equals( settings.FlightCameraControlType, "WASD_Always", StringComparison.Ordinal ) &&
				!String.Equals( settings.FlightCameraControlType, "WASD_RMBOnly", StringComparison.Ordinal ) &&
				!String.Equals( settings.FlightCameraControlType, "WASD_Never", StringComparison.Ordinal ) )
			{
				throw new InvalidOperationException( "Choose a valid flight-camera control mode." );
			}
		}

		private string GetFlightCameraControlType()
		{
			string value = settingsFile.GetValue( EditorSection, "FlightCameraControlType", "WASD_Always" );
			if( String.Equals( value, "WASD_RMBOnly", StringComparison.Ordinal ) || String.Equals( value, "WASD_Never", StringComparison.Ordinal ) )
			{
				return value;
			}
			return "WASD_Always";
		}

		private bool GetBool( string section, string key, bool fallback )
		{
			string rawValue = settingsFile.GetValue( section, key, fallback ? "True" : "False" );
			bool parsed;
			if( Boolean.TryParse( rawValue, out parsed ) )
			{
				return parsed;
			}
			int numeric;
			return Int32.TryParse( rawValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out numeric ) ? numeric != 0 : fallback;
		}

		private int GetInt( string section, string key, int fallback, int min, int max )
		{
			int parsed;
			if( !Int32.TryParse( settingsFile.GetValue( section, key, fallback.ToString( CultureInfo.InvariantCulture ) ), NumberStyles.Integer, CultureInfo.InvariantCulture, out parsed ) )
			{
				return fallback;
			}
			return Math.Max( min, Math.Min( max, parsed ) );
		}

		private decimal GetDecimal( string section, string key, decimal fallback, decimal min, decimal max )
		{
			decimal parsed;
			if( !Decimal.TryParse( settingsFile.GetValue( section, key, fallback.ToString( CultureInfo.InvariantCulture ) ), NumberStyles.Float, CultureInfo.InvariantCulture, out parsed ) )
			{
				return fallback;
			}
			return Math.Max( min, Math.Min( max, parsed ) );
		}

		private static string ToIniBool( bool value )
		{
			return value ? "True" : "False";
		}
	}
}
