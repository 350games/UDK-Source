using System;
using System.Drawing;
using System.Windows.Forms;

namespace UE3Workbench
{
	internal sealed class MainForm : Form
	{
		private readonly string workspaceRoot;

		public MainForm( string workspaceRoot )
		{
			this.workspaceRoot = workspaceRoot;
			InitializeComponent();
		}

		private void InitializeComponent()
		{
			Text = "UE3 Workbench — UTGame";
			StartPosition = FormStartPosition.CenterScreen;
			ClientSize = new Size( 700, 430 );
			MinimumSize = new Size( 620, 390 );
			BackColor = Color.FromArgb( 28, 32, 36 );
			ForeColor = Color.FromArgb( 232, 229, 220 );
			Font = new Font( "Segoe UI", 9.0f );

			MenuStrip menu = new MenuStrip();
			menu.BackColor = Color.FromArgb( 38, 43, 48 );
			menu.ForeColor = ForeColor;
			menu.RenderMode = ToolStripRenderMode.System;

			ToolStripMenuItem fileMenu = new ToolStripMenuItem( "File" );
			ToolStripMenuItem settingsMenu = new ToolStripMenuItem( "Settings" );
			ToolStripMenuItem projectSettingsItem = new ToolStripMenuItem( "Project Settings…" );
			projectSettingsItem.ShortcutKeys = Keys.Control | Keys.Shift | Keys.P;
			projectSettingsItem.Click += OpenProjectSettings;
			ToolStripMenuItem editorSettingsItem = new ToolStripMenuItem( "Editor Settings…" );
			editorSettingsItem.ShortcutKeys = Keys.Control | Keys.Shift | Keys.E;
			editorSettingsItem.Click += OpenEditorSettings;
			settingsMenu.DropDownItems.Add( projectSettingsItem );
			settingsMenu.DropDownItems.Add( new ToolStripSeparator() );
			settingsMenu.DropDownItems.Add( editorSettingsItem );
			ToolStripMenuItem toolsMenu = new ToolStripMenuItem( "Tools" );
			ToolStripMenuItem helpMenu = new ToolStripMenuItem( "Help" );
			menu.Items.AddRange( new ToolStripItem[] { fileMenu, settingsMenu, toolsMenu, helpMenu } );
			MainMenuStrip = menu;
			Panel content = new Panel();
			content.BackColor = Color.FromArgb( 32, 37, 42 );
			content.BorderStyle = BorderStyle.FixedSingle;
			content.Dock = DockStyle.Fill;
			content.Padding = new Padding( 34, 30, 34, 30 );
			Controls.Add( content );
			Controls.Add( menu );

			Label eyebrow = new Label();
			eyebrow.AutoSize = true;
			eyebrow.Font = new Font( Font, FontStyle.Bold );
			eyebrow.ForeColor = Color.FromArgb( 228, 145, 56 );
			eyebrow.Location = new Point( 34, 36 );
			eyebrow.Text = "UE3 WORKBENCH";
			content.Controls.Add( eyebrow );

			Label title = new Label();
			title.AutoSize = true;
			title.Font = new Font( "Georgia", 20.0f, FontStyle.Regular );
			title.ForeColor = Color.FromArgb( 246, 241, 231 );
			title.Location = new Point( 31, 58 );
			title.Text = "Project & Editor Settings";
			content.Controls.Add( title );

			Label description = new Label();
			description.AutoSize = false;
			description.ForeColor = Color.FromArgb( 194, 200, 202 );
			description.Location = new Point( 35, 108 );
			description.MaximumSize = new Size( 580, 0 );
			description.Size = new Size( 580, 60 );
			description.Text = "Open Project Settings for Rendering, Plugins, and Misc project configuration. " +
				"Open Editor Settings for editor behavior, viewport preferences, saving, source control, and Splash & Branding.";
			content.Controls.Add( description );

			Button openButton = new Button();
			openButton.BackColor = Color.FromArgb( 171, 91, 38 );
			openButton.FlatStyle = FlatStyle.Flat;
			openButton.FlatAppearance.BorderColor = Color.FromArgb( 247, 177, 99 );
			openButton.ForeColor = Color.White;
			openButton.Location = new Point( 35, 190 );
			openButton.Size = new Size( 172, 36 );
			openButton.Text = "Editor Settings";
			openButton.UseVisualStyleBackColor = false;
			openButton.Click += OpenEditorSettings;
			content.Controls.Add( openButton );

			Button openProjectButton = new Button();
			openProjectButton.BackColor = Color.FromArgb( 55, 62, 68 );
			openProjectButton.FlatStyle = FlatStyle.Flat;
			openProjectButton.FlatAppearance.BorderColor = Color.FromArgb( 116, 126, 130 );
			openProjectButton.ForeColor = Color.FromArgb( 244, 239, 229 );
			openProjectButton.Location = new Point( 216, 190 );
			openProjectButton.Size = new Size( 172, 36 );
			openProjectButton.Text = "Project Settings";
			openProjectButton.UseVisualStyleBackColor = false;
			openProjectButton.Click += OpenProjectSettings;
			content.Controls.Add( openProjectButton );

			Label footer = new Label();
			footer.AutoSize = false;
			footer.Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom;
			footer.ForeColor = Color.FromArgb( 139, 151, 156 );
			footer.Location = new Point( 34, 344 );
			footer.Size = new Size( 610, 28 );
			footer.Text = "Project: Rendering · Plugins · Misc    Editor: Preferences · Splash & Branding";
			content.Controls.Add( footer );
		}

		private void OpenEditorSettings( object sender, EventArgs eventArgs )
		{
			using( EditorSettingsForm settings = new EditorSettingsForm( workspaceRoot ) )
			{
				settings.ShowDialog( this );
			}
		}

		private void OpenProjectSettings( object sender, EventArgs eventArgs )
		{
			using( ProjectSettingsForm settings = new ProjectSettingsForm( workspaceRoot ) )
			{
				settings.ShowDialog( this );
			}
		}
	}
}
