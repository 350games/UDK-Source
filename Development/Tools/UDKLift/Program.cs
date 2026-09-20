/**
 * Copyright 1998-2013 Epic Games, Inc. All Rights Reserved.
 */

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Windows.Forms;

namespace UDKLift
{
	static class Program
	{
		/// <summary>
		/// The main entry point for the application.
		/// </summary>
		[STAThread]
		static int Main( string[] Arguments )
		{
			string[] NormalizedArguments = NormalizeLaunchArguments( Arguments );

			Application.EnableVisualStyles();
			Application.SetCompatibleTextRenderingDefault( false );

			string CommandLine = BuildCommandLine( NormalizedArguments );
			bool bRequiresElevation = RequiresElevation( NormalizedArguments );

			// Run the application, elevating if required...
			// Parse the executable name to remove the 'Lift' component...
			string ExecutableName = GetTargetExecutableName( Application.ExecutablePath );
			string BinariesFolder = Application.StartupPath;
			string BitFolder = Environment.Is64BitOperatingSystem ? "Win64" : "Win32";
			string WorkingDirectory = Path.Combine( BinariesFolder, BitFolder );
			string TargetExecutable = Path.Combine( WorkingDirectory, ExecutableName );

			if( File.Exists( TargetExecutable ) == false )
			{
				ShowLaunchError(
					"The UDK executable could not be found.\n\nExpected location:\n" + TargetExecutable +
					"\n\nBuild the " + BitFolder + " UDK editor target before running UDKLift.exe." );
				return 2;
			}

			try
			{
				Process LaunchProcess = new Process();
				LaunchProcess.StartInfo.FileName = TargetExecutable;
				LaunchProcess.StartInfo.Arguments = CommandLine;
				LaunchProcess.StartInfo.WorkingDirectory = WorkingDirectory;
				LaunchProcess.StartInfo.UseShellExecute = true;
				if( bRequiresElevation == true )
				{
					if( CanWriteToFolder( BinariesFolder ) == false )
					{
						LaunchProcess.StartInfo.Verb = "runas";
					}
				}

				LaunchProcess.Start();
			}
			catch( Win32Exception Error )
			{
				// Keep UAC cancellation quiet, but do not hide real launch failures.
				const int ErrorCancelled = 1223;
				if( Error.NativeErrorCode != ErrorCancelled )
				{
					ShowLaunchError(
						"UDKLift could not start:\n" + TargetExecutable + "\n\n" +
						Error.Message + " (Windows error " + Error.NativeErrorCode.ToString() + ")" );
					return 1;
				}
			}
			catch( Exception Error )
			{
				ShowLaunchError(
					"UDKLift could not start:\n" + TargetExecutable + "\n\n" + Error.Message );
				return 1;
			}

			return 0;
		}

		private static string[] NormalizeLaunchArguments( string[] Arguments )
		{
			if( Arguments == null )
			{
				return new string[ 0 ];
			}

			string[] Result = new string[ Arguments.Length ];
			for( int ArgumentIndex = 0; ArgumentIndex < Arguments.Length; ++ArgumentIndex )
			{
				string Argument = Arguments[ ArgumentIndex ] ?? String.Empty;
				Result[ ArgumentIndex ] = IsCommandToken( Argument, "editor" ) ? "editor" : Argument;
			}

			return Result;
		}

		private static bool RequiresElevation( string[] Arguments )
		{
			foreach( string Argument in Arguments )
			{
				if( IsCommandToken( Argument, "editor" ) ||
					IsCommandToken( Argument, "make" ) ||
					IsCommandToken( Argument, "cookpackages" ) )
				{
					return true;
				}
			}

			return false;
		}

		private static bool IsCommandToken( string Argument, string ExpectedToken )
		{
			if( Argument == null )
			{
				return false;
			}

			string Token = Argument.Trim().TrimStart( '-', '/' );
			return String.Equals( Token, ExpectedToken, StringComparison.OrdinalIgnoreCase );
		}

		private static string GetTargetExecutableName( string LauncherPath )
		{
			string LauncherName = Path.GetFileNameWithoutExtension( LauncherPath );
			if( LauncherName.EndsWith( "Lift", StringComparison.OrdinalIgnoreCase ) )
			{
				LauncherName = LauncherName.Substring( 0, LauncherName.Length - "Lift".Length );
			}

			return LauncherName + Path.GetExtension( LauncherPath );
		}

		private static string BuildCommandLine( string[] Arguments )
		{
			StringBuilder CommandLine = new StringBuilder();
			foreach( string Argument in Arguments )
			{
				if( CommandLine.Length > 0 )
				{
					CommandLine.Append( ' ' );
				}

				AppendQuotedArgument( CommandLine, Argument ?? String.Empty );
			}

			return CommandLine.ToString();
		}

		private static void AppendQuotedArgument( StringBuilder CommandLine, string Argument )
		{
			if( Argument.Length > 0 && Argument.IndexOfAny( new char[] { ' ', '\t', '"' } ) < 0 )
			{
				CommandLine.Append( Argument );
				return;
			}

			CommandLine.Append( '"' );
			int BackslashCount = 0;
			foreach( char Character in Argument )
			{
				if( Character == '\\' )
				{
					++BackslashCount;
					continue;
				}

				if( Character == '"' )
				{
					CommandLine.Append( '\\', BackslashCount * 2 + 1 );
					CommandLine.Append( '"' );
					BackslashCount = 0;
					continue;
				}

				CommandLine.Append( '\\', BackslashCount );
				BackslashCount = 0;
				CommandLine.Append( Character );
			}

			CommandLine.Append( '\\', BackslashCount * 2 );
			CommandLine.Append( '"' );
		}

		private static bool CanWriteToFolder( string Folder )
		{
			string TestFilename = Path.Combine( Folder, "UDK_" + Guid.NewGuid().ToString() + ".tmp" );
			try
			{
				using( FileStream TestFile = new FileStream( TestFilename, FileMode.CreateNew, FileAccess.Write, FileShare.None ) )
				using( StreamWriter Writer = new StreamWriter( TestFile ) )
				{
					Writer.Write( "TESTING TESTING" );
				}

				return true;
			}
			catch
			{
				return false;
			}
			finally
			{
				try
				{
					if( File.Exists( TestFilename ) )
					{
						File.Delete( TestFilename );
					}
				}
				catch
				{
				}
			}
		}

		private static void ShowLaunchError( string Message )
		{
			MessageBox.Show( Message, "UDKLift", MessageBoxButtons.OK, MessageBoxIcon.Error );
		}
	}
}
