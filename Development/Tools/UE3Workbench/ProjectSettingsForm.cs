using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace UE3Workbench
{
	/// <summary>
	/// The project-facing companion to <see cref="EditorSettingsForm"/>.  This
	/// deliberately keeps the first Project Settings pass presentation-only:
	/// selecting a future renderer or plugin option must not imply that a new
	/// UE3 renderer or plugin host already exists.
	/// </summary>
	internal sealed class ProjectSettingsForm : Form
	{
		private const int DarkPanelRed = 35;
		private const int DarkPanelGreen = 40;
		private const int DarkPanelBlue = 45;

		private readonly string workspaceRoot;
		private readonly ProjectSettingsStore projectSettings;
		private ProjectSettingsData loadedSettings;
		private bool loadingSettings;
		private ComboBox rendererCombo;
		private ComboBox shaderModelCombo;
		private CheckBox hdrCheckBox;
		private CheckBox threadedRendererCheckBox;
		private CheckBox allowOpenGlCheckBox;
		private CheckBox highQualityMaterialsCheckBox;
		private CheckBox postprocessMlAaCheckBox;
		private CheckBox vsyncCheckBox;
		private CheckBox localPluginsCheckBox;
		private CheckBox unsignedPluginsCheckBox;
		private TextBox projectTitleTextBox;
		private ComboBox startupMapCombo;
		private CheckBox buildLogCheckBox;
		private CheckBox diagnosticsCheckBox;
		private CheckBox experimentalWarningCheckBox;
		private Label statusLabel;
		private TabControl settingsTabs;

		public ProjectSettingsForm( string workspaceRoot )
		{
			this.workspaceRoot = workspaceRoot;
			projectSettings = new ProjectSettingsStore( workspaceRoot );
			InitializeComponent();
			LoadSettings();
		}

		private void InitializeComponent()
		{
			Text = "Project Settings — " + GetProjectName();
			StartPosition = FormStartPosition.CenterParent;
			ClientSize = new Size( 790, 558 );
			FormBorderStyle = FormBorderStyle.FixedDialog;
			MaximizeBox = false;
			MinimizeBox = false;
			ShowInTaskbar = false;
			BackColor = Color.FromArgb( DarkPanelRed, DarkPanelGreen, DarkPanelBlue );
			ForeColor = Color.FromArgb( 233, 229, 220 );
			Font = new Font( "Segoe UI", 9.0f );

			Label title = new Label();
			title.AutoSize = true;
			title.Font = new Font( "Georgia", 17.0f );
			title.ForeColor = Color.FromArgb( 247, 241, 229 );
			title.Location = new Point( 20, 17 );
			title.Text = "Project Settings";
			Controls.Add( title );

			Label subtitle = new Label();
			subtitle.AutoSize = true;
			subtitle.Font = new Font( Font, FontStyle.Bold );
			subtitle.ForeColor = Color.FromArgb( 227, 145, 56 );
			subtitle.Location = new Point( 23, 50 );
			subtitle.Text = GetProjectName().ToUpperInvariant() + " PROJECT";
			Controls.Add( subtitle );

			Label guidance = new Label();
			guidance.AutoSize = false;
			guidance.ForeColor = Color.FromArgb( 195, 202, 204 );
			guidance.Location = new Point( 23, 75 );
			guidance.Size = new Size( 740, 27 );
			guidance.Text = "Configure project-level rendering, plugin, and miscellaneous behavior. " +
				"Only settings backed by this build are written to engine configuration; future backends are kept as explicit project intent.";
			Controls.Add( guidance );

			settingsTabs = new TabControl();
			settingsTabs.Location = new Point( 20, 109 );
			settingsTabs.Size = new Size( 750, 356 );
			settingsTabs.Font = new Font( Font, FontStyle.Bold );
			settingsTabs.SelectedIndexChanged += SettingsTabChanged;
			Controls.Add( settingsTabs );

			TabPage renderingPage = CreatePage( "Rendering" );
			BuildRenderingPage( renderingPage );
			settingsTabs.TabPages.Add( renderingPage );

			TabPage pluginsPage = CreatePage( "Plugins" );
			BuildPluginsPage( pluginsPage );
			settingsTabs.TabPages.Add( pluginsPage );

			TabPage miscPage = CreatePage( "Misc" );
			BuildMiscPage( miscPage );
			settingsTabs.TabPages.Add( miscPage );

			statusLabel = new Label();
			statusLabel.AutoSize = false;
			statusLabel.ForeColor = Color.FromArgb( 185, 194, 196 );
			statusLabel.Location = new Point( 23, 475 );
			statusLabel.Size = new Size( 570, 30 );
			statusLabel.Text = "Changes are saved only when you click Apply. Close the editor before changing project configuration.";
			Controls.Add( statusLabel );

			Button revertButton = CreateButton( "Revert", new Point( 502, 510 ), new Size( 82, 31 ), false );
			revertButton.Click += ReloadSavedSettings;
			Controls.Add( revertButton );

			Button applyButton = CreateButton( "Apply", new Point( 592, 510 ), new Size( 82, 31 ), true );
			applyButton.Click += SaveSettings;
			Controls.Add( applyButton );

			Button closeButton = CreateButton( "Close", new Point( 682, 510 ), new Size( 82, 31 ), false );
			closeButton.DialogResult = DialogResult.Cancel;
			Controls.Add( closeButton );

			AcceptButton = applyButton;
			CancelButton = closeButton;
		}

		private TabPage CreatePage( string title )
		{
			TabPage page = new TabPage( title );
			page.BackColor = Color.FromArgb( 31, 36, 40 );
			page.ForeColor = ForeColor;
			page.Padding = new Padding( 0 );
			return page;
		}

		private void BuildRenderingPage( TabPage page )
		{
			GroupBox rendererBox = CreateGroupBox( "Render device", new Point( 14, 13 ), new Size( 710, 124 ) );
			page.Controls.Add( rendererBox );

			Label rendererLabel = CreateLabel( "Preferred rendering path", new Point( 18, 30 ), new Size( 285, 18 ), Color.FromArgb( 220, 222, 218 ) );
			rendererBox.Controls.Add( rendererLabel );

			rendererCombo = new ComboBox();
			rendererCombo.BackColor = Color.FromArgb( 48, 55, 61 );
			rendererCombo.DropDownStyle = ComboBoxStyle.DropDownList;
			rendererCombo.ForeColor = Color.FromArgb( 240, 237, 228 );
			rendererCombo.Items.AddRange( new object[]
			{
				"Direct3D 9 — stock UE3 renderer",
				"Direct3D 11 — renderer extension required",
				"Direct3D 12 — renderer extension required",
				"Vulkan — renderer extension required",
				"OpenGL — renderer extension required"
			} );
			rendererCombo.Location = new Point( 18, 51 );
			rendererCombo.SelectedIndex = 0;
			rendererCombo.Size = new Size( 360, 23 );
			rendererCombo.SelectedIndexChanged += DraftSettingChanged;
			rendererBox.Controls.Add( rendererCombo );

			Label rendererNote = CreateLabel(
				"Direct3D 9 is the current engine path. Other choices are saved as project intent only until a renderer extension is installed.",
				new Point( 18, 84 ), new Size( 670, 28 ), Color.FromArgb( 184, 195, 197 ) );
			rendererBox.Controls.Add( rendererNote );

			GroupBox shaderBox = CreateGroupBox( "Shaders & presentation", new Point( 14, 148 ), new Size( 710, 165 ) );
			page.Controls.Add( shaderBox );

			Label shaderLabel = CreateLabel( "Preferred shader feature level", new Point( 18, 30 ), new Size( 210, 18 ), Color.FromArgb( 220, 222, 218 ) );
			shaderBox.Controls.Add( shaderLabel );

			shaderModelCombo = new ComboBox();
			shaderModelCombo.BackColor = Color.FromArgb( 48, 55, 61 );
			shaderModelCombo.DropDownStyle = ComboBoxStyle.DropDownList;
			shaderModelCombo.ForeColor = Color.FromArgb( 240, 237, 228 );
			shaderModelCombo.Items.AddRange( new object[]
			{
				"Shader Model 3 — stock UE3 content path",
				"Shader Model 5 — renderer and shader compiler extension required"
			} );
			shaderModelCombo.Location = new Point( 18, 51 );
			shaderModelCombo.SelectedIndex = 0;
			shaderModelCombo.Size = new Size( 420, 23 );
			shaderModelCombo.SelectedIndexChanged += DraftSettingChanged;
			shaderBox.Controls.Add( shaderModelCombo );

			hdrCheckBox = CreateOption( "Request HDR framebuffer support", new Point( 18, 82 ), "Saved as a renderer capability request." );
			shaderBox.Controls.Add( hdrCheckBox );

			threadedRendererCheckBox = CreateOption( "Request multi-threaded rendering", new Point( 360, 82 ), "Saved as a renderer capability request." );
			shaderBox.Controls.Add( threadedRendererCheckBox );

			Label engineOptionsLabel = CreateLabel( "Current UE3 graphics configuration", new Point( 18, 109 ), new Size( 270, 18 ), Color.FromArgb( 220, 222, 218 ) );
			shaderBox.Controls.Add( engineOptionsLabel );

			allowOpenGlCheckBox = CreateOption( "Allow OpenGL initialization", new Point( 18, 132 ), "Writes AllowOpenGL in UTSystemSettings.ini; this does not add an OpenGL renderer." );
			shaderBox.Controls.Add( allowOpenGlCheckBox );

			highQualityMaterialsCheckBox = CreateOption( "High quality materials", new Point( 220, 132 ), "Writes bAllowHighQualityMaterials in UTSystemSettings.ini." );
			shaderBox.Controls.Add( highQualityMaterialsCheckBox );

			postprocessMlAaCheckBox = CreateOption( "Post-process MLAA", new Point( 420, 132 ), "Writes bAllowPostprocessMLAA in UTSystemSettings.ini." );
			shaderBox.Controls.Add( postprocessMlAaCheckBox );

			vsyncCheckBox = CreateOption( "Vertical sync", new Point( 584, 132 ), "Writes UseVsync in UTSystemSettings.ini." );
			shaderBox.Controls.Add( vsyncCheckBox );
		}

		private void BuildPluginsPage( TabPage page )
		{
			GroupBox loadingBox = CreateGroupBox( "Plugin loading", new Point( 14, 13 ), new Size( 710, 116 ) );
			page.Controls.Add( loadingBox );

			localPluginsCheckBox = CreateOption( "Enable project-local plugins", new Point( 18, 30 ), "Discover plugins from the project plugin folder when a plugin host is available." );
			loadingBox.Controls.Add( localPluginsCheckBox );

			unsignedPluginsCheckBox = CreateOption( "Allow unsigned development plugins", new Point( 18, 61 ), "For locally built tools during development only." );
			loadingBox.Controls.Add( unsignedPluginsCheckBox );

			Label loadingNote = CreateLabel(
				"Plugin discovery and loading are intentionally not active until the Workbench defines a compatible plugin manifest and host contract.",
				new Point( 18, 88 ), new Size( 670, 18 ), Color.FromArgb( 184, 195, 197 ) );
			loadingBox.Controls.Add( loadingNote );

			GroupBox inventoryBox = CreateGroupBox( "Project plugin inventory", new Point( 14, 140 ), new Size( 710, 173 ) );
			page.Controls.Add( inventoryBox );

			Label folderLabel = CreateLabel( "Reserved plugin folder: " + GetPluginFolder(), new Point( 18, 29 ), new Size( 670, 18 ), Color.FromArgb( 210, 216, 216 ) );
			inventoryBox.Controls.Add( folderLabel );

			ListView pluginList = new ListView();
			pluginList.BackColor = Color.FromArgb( 25, 29, 33 );
			pluginList.BorderStyle = BorderStyle.FixedSingle;
			pluginList.ForeColor = Color.FromArgb( 225, 228, 220 );
			pluginList.FullRowSelect = true;
			pluginList.HeaderStyle = ColumnHeaderStyle.Nonclickable;
			pluginList.Location = new Point( 18, 55 );
			pluginList.Size = new Size( 672, 103 );
			pluginList.View = View.Details;
			pluginList.Columns.Add( "Component", 176 );
			pluginList.Columns.Add( "Status", 110 );
			pluginList.Columns.Add( "Details", 370 );
			pluginList.Items.Add( new ListViewItem( new[]
			{
				"Project plugin host",
				"Not installed",
				"A future Workbench plugin host will populate this list."
			} ) );
			pluginList.Items.Add( new ListViewItem( new[]
			{
				"Load order",
				"Reserved",
				"Will be configured after manifest discovery is implemented."
			} ) );
			inventoryBox.Controls.Add( pluginList );
		}

		private void BuildMiscPage( TabPage page )
		{
			GroupBox identityBox = CreateGroupBox( "Project identity", new Point( 14, 13 ), new Size( 710, 125 ) );
			page.Controls.Add( identityBox );

			Label projectTitleLabel = CreateLabel( "Project display name", new Point( 18, 30 ), new Size( 155, 18 ), Color.FromArgb( 220, 222, 218 ) );
			identityBox.Controls.Add( projectTitleLabel );

			projectTitleTextBox = CreateTextBox( GetProjectName(), new Point( 18, 51 ), new Size( 300, 23 ) );
			identityBox.Controls.Add( projectTitleTextBox );

			Label startupMapLabel = CreateLabel( "Default startup map", new Point( 360, 30 ), new Size( 155, 18 ), Color.FromArgb( 220, 222, 218 ) );
			identityBox.Controls.Add( startupMapLabel );

			startupMapCombo = new ComboBox();
			startupMapCombo.BackColor = Color.FromArgb( 48, 55, 61 );
			startupMapCombo.DropDownStyle = ComboBoxStyle.DropDownList;
			startupMapCombo.ForeColor = Color.FromArgb( 240, 237, 228 );
			startupMapCombo.Location = new Point( 360, 51 );
			startupMapCombo.Size = new Size( 330, 23 );
			startupMapCombo.SelectedIndexChanged += DraftSettingChanged;
			identityBox.Controls.Add( startupMapCombo );

			Label identityNote = CreateLabel(
				"The chosen map is written to [URL] Map and LocalMap in DefaultEngine.ini and the local UTEngine.ini runtime configuration.",
				new Point( 18, 88 ), new Size( 670, 22 ), Color.FromArgb( 184, 195, 197 ) );
			identityBox.Controls.Add( identityNote );

			GroupBox behaviorBox = CreateGroupBox( "Build & diagnostics", new Point( 14, 149 ), new Size( 710, 164 ) );
			page.Controls.Add( behaviorBox );

			buildLogCheckBox = CreateOption( "Keep detailed Workbench build logs", new Point( 18, 30 ), "Retain more information when project tools are invoked." );
			behaviorBox.Controls.Add( buildLogCheckBox );

			diagnosticsCheckBox = CreateOption( "Keep startup diagnostics", new Point( 18, 61 ), "Show compatibility information when the editor is launched." );
			behaviorBox.Controls.Add( diagnosticsCheckBox );

			experimentalWarningCheckBox = CreateOption( "Warn before selecting experimental rendering paths", new Point( 18, 92 ), "Keeps unsupported paths explicit during development." );
			behaviorBox.Controls.Add( experimentalWarningCheckBox );

			Label behaviorNote = CreateLabel(
				"Command entry remains a separate Tools window, matching the editor workflow rather than adding a console to Project Settings.",
				new Point( 18, 125 ), new Size( 670, 21 ), Color.FromArgb( 184, 195, 197 ) );
			behaviorBox.Controls.Add( behaviorNote );
		}

		private GroupBox CreateGroupBox( string title, Point location, Size size )
		{
			GroupBox box = new GroupBox();
			box.ForeColor = Color.FromArgb( 233, 229, 220 );
			box.Location = location;
			box.Size = size;
			box.Text = title;
			return box;
		}

		private Label CreateLabel( string text, Point location, Size size, Color color )
		{
			Label label = new Label();
			label.AutoSize = false;
			label.ForeColor = color;
			label.Location = location;
			label.Size = size;
			label.Text = text;
			return label;
		}

		private CheckBox CreateOption( string title, Point location, string tooltip )
		{
			CheckBox option = new CheckBox();
			option.AutoSize = true;
			option.ForeColor = Color.FromArgb( 230, 230, 221 );
			option.Location = location;
			option.Text = title;
			option.CheckedChanged += DraftSettingChanged;
			ToolTip toolTip = new ToolTip();
			toolTip.SetToolTip( option, tooltip );
			return option;
		}

		private TextBox CreateTextBox( string text, Point location, Size size )
		{
			TextBox textBox = new TextBox();
			textBox.BackColor = Color.FromArgb( 48, 55, 61 );
			textBox.ForeColor = Color.FromArgb( 240, 237, 228 );
			textBox.Location = location;
			textBox.Size = size;
			textBox.Text = text;
			textBox.TextChanged += DraftSettingChanged;
			return textBox;
		}

		private Button CreateButton( string title, Point location, Size size, bool accent )
		{
			Button button = new Button();
			button.FlatStyle = FlatStyle.Flat;
			button.Location = location;
			button.Size = size;
			button.Text = title;
			button.UseVisualStyleBackColor = false;
			if( accent )
			{
				button.BackColor = Color.FromArgb( 174, 92, 37 );
				button.FlatAppearance.BorderColor = Color.FromArgb( 247, 177, 99 );
				button.ForeColor = Color.White;
			}
			else
			{
				button.BackColor = Color.FromArgb( 55, 62, 68 );
				button.FlatAppearance.BorderColor = Color.FromArgb( 99, 109, 113 );
				button.ForeColor = ForeColor;
			}
			return button;
		}

		private void DraftSettingChanged( object sender, EventArgs eventArgs )
		{
			if( !loadingSettings && statusLabel != null )
			{
				statusLabel.ForeColor = Color.FromArgb( 227, 183, 99 );
				statusLabel.Text = "Unsaved project settings. Click Apply to write supported engine settings and record future-feature intent.";
			}
		}

		private void SettingsTabChanged( object sender, EventArgs eventArgs )
		{
			if( !loadingSettings && statusLabel != null )
			{
				statusLabel.ForeColor = Color.FromArgb( 185, 194, 196 );
				statusLabel.Text = settingsTabs.SelectedTab.Text + " settings are project-scoped; no editor-wide options are included here.";
			}
		}

		private void LoadSettings()
		{
			loadingSettings = true;
			try
			{
				loadedSettings = projectSettings.Load();
				projectTitleTextBox.Text = loadedSettings.ProjectDisplayName;
				LoadStartupMaps( loadedSettings.StartupMap );
				SelectRendererIntent( loadedSettings.RendererIntent );
				SelectShaderModelIntent( loadedSettings.ShaderModelIntent );
				hdrCheckBox.Checked = loadedSettings.RequestHdr;
				threadedRendererCheckBox.Checked = loadedSettings.RequestThreadedRenderer;
				allowOpenGlCheckBox.Checked = loadedSettings.AllowOpenGl;
				highQualityMaterialsCheckBox.Checked = loadedSettings.AllowHighQualityMaterials;
				postprocessMlAaCheckBox.Checked = loadedSettings.AllowPostprocessMlAa;
				vsyncCheckBox.Checked = loadedSettings.UseVsync;
				localPluginsCheckBox.Checked = loadedSettings.EnableLocalPlugins;
				unsignedPluginsCheckBox.Checked = loadedSettings.AllowUnsignedPlugins;
				buildLogCheckBox.Checked = loadedSettings.KeepBuildLogs;
				diagnosticsCheckBox.Checked = loadedSettings.KeepStartupDiagnostics;
				experimentalWarningCheckBox.Checked = loadedSettings.WarnExperimentalRenderer;

				statusLabel.ForeColor = Color.FromArgb( 185, 194, 196 );
				statusLabel.Text = "Loaded project configuration. Nothing has been changed on disk.";
			}
			catch( Exception error )
			{
				statusLabel.ForeColor = Color.FromArgb( 239, 139, 126 );
				statusLabel.Text = error.Message;
			}
			finally
			{
				loadingSettings = false;
			}
		}

		private void LoadStartupMaps( string selectedMap )
		{
			startupMapCombo.Items.Clear();
			foreach( string map in projectSettings.GetAvailableMaps() )
			{
				startupMapCombo.Items.Add( map );
			}

			string normalizedSelection = ( selectedMap ?? String.Empty ).Replace( '/', '\\' );
			if( startupMapCombo.Items.IndexOf( normalizedSelection ) < 0 && !String.IsNullOrWhiteSpace( normalizedSelection ) )
			{
				startupMapCombo.Items.Add( normalizedSelection );
			}
			if( startupMapCombo.Items.Count > 0 )
			{
				startupMapCombo.SelectedItem = normalizedSelection;
				if( startupMapCombo.SelectedIndex < 0 )
				{
					startupMapCombo.SelectedIndex = 0;
				}
			}
		}

		private void SaveSettings( object sender, EventArgs eventArgs )
		{
			try
			{
				ProjectSettingsData settings = new ProjectSettingsData();
				settings.StartupMap = startupMapCombo.SelectedItem == null ? String.Empty : startupMapCombo.SelectedItem.ToString();
				settings.ProjectDisplayName = projectTitleTextBox.Text;
				settings.RendererIntent = GetRendererIntent();
				settings.ShaderModelIntent = GetShaderModelIntent();
				settings.RequestHdr = hdrCheckBox.Checked;
				settings.RequestThreadedRenderer = threadedRendererCheckBox.Checked;
				settings.AllowOpenGl = allowOpenGlCheckBox.Checked;
				settings.AllowHighQualityMaterials = highQualityMaterialsCheckBox.Checked;
				settings.AllowPostprocessMlAa = postprocessMlAaCheckBox.Checked;
				settings.UseVsync = vsyncCheckBox.Checked;
				settings.EnableLocalPlugins = localPluginsCheckBox.Checked;
				settings.AllowUnsignedPlugins = unsignedPluginsCheckBox.Checked;
				settings.KeepBuildLogs = buildLogCheckBox.Checked;
				settings.KeepStartupDiagnostics = diagnosticsCheckBox.Checked;
				settings.WarnExperimentalRenderer = experimentalWarningCheckBox.Checked;

				projectSettings.Save( settings );
				loadedSettings = settings;
				statusLabel.ForeColor = Color.FromArgb( 166, 213, 137 );
				statusLabel.Text = "Saved. Startup-map and graphics values are in project configuration; renderer and plugin requests stay marked as intent until their backend exists.";
			}
			catch( Exception error )
			{
				statusLabel.ForeColor = Color.FromArgb( 239, 139, 126 );
				statusLabel.Text = error.Message;
			}
		}

		private void ReloadSavedSettings( object sender, EventArgs eventArgs )
		{
			LoadSettings();
		}

		private void SelectRendererIntent( string rendererIntent )
		{
			int index = 0;
			if( String.Equals( rendererIntent, "D3D11", StringComparison.OrdinalIgnoreCase ) )
			{
				index = 1;
			}
			else if( String.Equals( rendererIntent, "D3D12", StringComparison.OrdinalIgnoreCase ) )
			{
				index = 2;
			}
			else if( String.Equals( rendererIntent, "Vulkan", StringComparison.OrdinalIgnoreCase ) )
			{
				index = 3;
			}
			else if( String.Equals( rendererIntent, "OpenGL", StringComparison.OrdinalIgnoreCase ) )
			{
				index = 4;
			}
			rendererCombo.SelectedIndex = index;
		}

		private string GetRendererIntent()
		{
			switch( rendererCombo.SelectedIndex )
			{
				case 1: return "D3D11";
				case 2: return "D3D12";
				case 3: return "Vulkan";
				case 4: return "OpenGL";
				default: return "D3D9";
			}
		}

		private void SelectShaderModelIntent( string shaderIntent )
		{
			shaderModelCombo.SelectedIndex = String.Equals( shaderIntent, "SM5", StringComparison.OrdinalIgnoreCase ) ? 1 : 0;
		}

		private string GetShaderModelIntent()
		{
			return shaderModelCombo.SelectedIndex == 1 ? "SM5" : "SM3";
		}

		private string GetProjectName()
		{
			string gameDirectory = Path.Combine( workspaceRoot, "UTGame" );
			return Directory.Exists( gameDirectory ) ? "UTGame" : "Project";
		}

		private string GetPluginFolder()
		{
			return Path.Combine( workspaceRoot, "UTGame", "Plugins" );
		}
	}
}
