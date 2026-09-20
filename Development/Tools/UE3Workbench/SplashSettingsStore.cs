using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;

namespace UE3Workbench
{
	internal enum SplashMode
	{
		Default,
		Custom
	}

	internal sealed class SplashSelection
	{
		public SplashMode Mode;
		public string CustomImagePath;
	}

	internal sealed class SplashSettingsStore
	{
		private const int SplashWidth = 650;
		private const int SplashHeight = 375;
		private const string SettingsSection = "UE3Workbench.Splash";

		private readonly string workspaceRoot;
		private readonly string gameSplashDirectory;
		private readonly string metadataPath;
		private readonly IniFileStore settingsFile;

		public SplashSettingsStore( string workspaceRoot )
		{
			this.workspaceRoot = workspaceRoot;
			gameSplashDirectory = Path.Combine( workspaceRoot, "UTGame", "Splash" );
			metadataPath = Path.Combine( workspaceRoot, "UTGame", "Config", "UE3Workbench.ini" );
			settingsFile = new IniFileStore( metadataPath );
		}

		public SplashSelection Load()
		{
			SplashSelection selection = new SplashSelection();
			selection.Mode = SplashMode.Default;
			selection.CustomImagePath = String.Empty;

			string modeValue = settingsFile.GetValue( SettingsSection, "Mode", String.Empty );
			SplashMode parsedMode;
			if( Enum.TryParse<SplashMode>( modeValue, true, out parsedMode ) )
			{
				selection.Mode = parsedMode;
			}
			selection.CustomImagePath = settingsFile.GetValue( SettingsSection, "CustomImage", String.Empty );

			return selection;
		}

		public string GetEditorSourcePath( SplashMode mode, string customImagePath )
		{
			switch( mode )
			{
				case SplashMode.Custom:
					return String.IsNullOrWhiteSpace( customImagePath ) ? String.Empty : customImagePath.Trim();
				default:
					return Path.Combine( workspaceRoot, "Binaries", "Splash", "EdSplash.bmp" );
			}
		}

		public void Apply( SplashMode mode, string customImagePath )
		{
			string editorSource = GetEditorSourcePath( mode, customImagePath );
			string gameSource = GetGameSourcePath( mode, customImagePath );
			bool isDefaultPreset = mode == SplashMode.Default;
			ValidateBitmap( editorSource, isDefaultPreset );
			ValidateBitmap( gameSource, isDefaultPreset );

			Directory.CreateDirectory( Path.Combine( gameSplashDirectory, "PC" ) );
			string backupDirectory = Path.Combine(
				gameSplashDirectory,
				"UE3Workbench",
				"Backups",
				DateTime.UtcNow.ToString( "yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture ) );

			ReplaceWithBackup( editorSource, Path.Combine( gameSplashDirectory, "PC", "EdSplash.bmp" ), backupDirectory );
			ReplaceWithBackup( gameSource, Path.Combine( gameSplashDirectory, "PC", "Splash.bmp" ), backupDirectory );
			WriteSelection( mode, mode == SplashMode.Custom ? customImagePath.Trim() : String.Empty );
		}

		private string GetGameSourcePath( SplashMode mode, string customImagePath )
		{
			switch( mode )
			{
				case SplashMode.Custom:
					return String.IsNullOrWhiteSpace( customImagePath ) ? String.Empty : customImagePath.Trim();
				default:
					return Path.Combine( workspaceRoot, "Binaries", "Splash", "Logo.bmp" );
			}
		}

		private static void ValidateBitmap( string filePath, bool allowIndexedSource )
		{
			if( String.IsNullOrWhiteSpace( filePath ) || !File.Exists( filePath ) )
			{
				throw new InvalidOperationException( "Choose an existing 650 × 375, 24-bit BMP image." );
			}
			if( !String.Equals( Path.GetExtension( filePath ), ".bmp", StringComparison.OrdinalIgnoreCase ) )
			{
				throw new InvalidOperationException( "Splash artwork must be a BMP file." );
			}

			try
			{
				using( Bitmap bitmap = new Bitmap( filePath ) )
				{
					if( bitmap.Width != SplashWidth || bitmap.Height != SplashHeight )
					{
						throw new InvalidOperationException(
							"Splash artwork must be exactly " + SplashWidth + " × " + SplashHeight + " pixels." );
					}
					if( bitmap.PixelFormat != PixelFormat.Format24bppRgb &&
						!( allowIndexedSource && bitmap.PixelFormat == PixelFormat.Format8bppIndexed ) )
					{
						throw new InvalidOperationException(
							"Custom splash artwork must be saved as a 24-bit BMP." );
					}
				}
			}
			catch( ArgumentException )
			{
				throw new InvalidOperationException( "The selected file is not a readable BMP image." );
			}
		}

		private static void ReplaceWithBackup( string sourcePath, string targetPath, string backupDirectory )
		{
			if( File.Exists( targetPath ) )
			{
				Directory.CreateDirectory( backupDirectory );
				string backupPath = Path.Combine( backupDirectory, Path.GetFileName( targetPath ) );
				File.Copy( targetPath, backupPath, true );
			}

			string targetDirectory = Path.GetDirectoryName( targetPath );
			Directory.CreateDirectory( targetDirectory );
			string temporaryPath = Path.Combine( targetDirectory, Path.GetFileName( targetPath ) + ".incoming-" + Guid.NewGuid().ToString( "N" ) );
			try
			{
				CopyAs24BitBitmap( sourcePath, temporaryPath );
				File.Copy( temporaryPath, targetPath, true );
			}
			finally
			{
				if( File.Exists( temporaryPath ) )
				{
					File.Delete( temporaryPath );
				}
			}
		}

		/** The supplied default artwork is indexed; write a native-safe 24-bit project override. */
		private static void CopyAs24BitBitmap( string sourcePath, string destinationPath )
		{
			using( Bitmap source = new Bitmap( sourcePath ) )
			using( Bitmap converted = new Bitmap( source.Width, source.Height, PixelFormat.Format24bppRgb ) )
			using( Graphics graphics = Graphics.FromImage( converted ) )
			{
				graphics.DrawImageUnscaled( source, 0, 0 );
				converted.Save( destinationPath, ImageFormat.Bmp );
			}
		}

		private void WriteSelection( SplashMode mode, string customImagePath )
		{
			settingsFile.SetValues(
				SettingsSection,
				new[]
				{
					new System.Collections.Generic.KeyValuePair<string, string>( "Mode", mode.ToString() ),
					new System.Collections.Generic.KeyValuePair<string, string>( "CustomImage", customImagePath )
				} );
		}
	}
}
