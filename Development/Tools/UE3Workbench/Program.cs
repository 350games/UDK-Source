using System;
using System.IO;
using System.Windows.Forms;

namespace UE3Workbench
{
	internal static class Program
	{
		[STAThread]
		private static int Main( string[] arguments )
		{
			Application.EnableVisualStyles();
			Application.SetCompatibleTextRenderingDefault( false );

			try
			{
				string workspaceRoot = FindWorkspaceRoot( Application.StartupPath );
				if( IsEditorSettingsRequest( arguments ) )
				{
					Application.Run( new EditorSettingsForm( workspaceRoot ) );
				}
				else if( IsProjectSettingsRequest( arguments ) )
				{
					Application.Run( new ProjectSettingsForm( workspaceRoot ) );
				}
				else
				{
					Application.Run( new MainForm( workspaceRoot ) );
				}
				return 0;
			}
			catch( Exception error )
			{
				MessageBox.Show(
					error.Message,
					"UE3 Workbench",
					MessageBoxButtons.OK,
					MessageBoxIcon.Error );
				return 1;
			}
		}

		private static bool IsEditorSettingsRequest( string[] arguments )
		{
			if( arguments == null || arguments.Length != 1 || arguments[ 0 ] == null )
			{
				return false;
			}

			string token = arguments[ 0 ].Trim().TrimStart( '-', '/' );
			return String.Equals( token, "editor-settings", StringComparison.OrdinalIgnoreCase ) ||
				String.Equals( token, "splash-settings", StringComparison.OrdinalIgnoreCase );
		}

		private static bool IsProjectSettingsRequest( string[] arguments )
		{
			if( arguments == null || arguments.Length != 1 || arguments[ 0 ] == null )
			{
				return false;
			}

			string token = arguments[ 0 ].Trim().TrimStart( '-', '/' );
			return String.Equals( token, "project-settings", StringComparison.OrdinalIgnoreCase );
		}

		private static string FindWorkspaceRoot( string binariesDirectory )
		{
			DirectoryInfo binaries = new DirectoryInfo( binariesDirectory );
			DirectoryInfo root = binaries.Parent;
			if( root == null ||
				!Directory.Exists( Path.Combine( root.FullName, "UTGame", "Config" ) ) ||
				!Directory.Exists( Path.Combine( root.FullName, "Engine", "Splash", "PC" ) ) ||
				!Directory.Exists( Path.Combine( root.FullName, "Binaries", "Splash" ) ) )
			{
				throw new InvalidOperationException(
					"UE3Workbench.exe must run from this build's Binaries folder. " +
					"The expected UTGame, Engine, and Binaries splash folders were not found." );
			}

			return root.FullName;
		}
	}
}
