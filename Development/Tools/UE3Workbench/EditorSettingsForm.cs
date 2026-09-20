using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace UE3Workbench
{
	internal sealed class EditorSettingsForm : Form
	{
		private readonly SplashSettingsStore splashSettings;
		private readonly EditorUserSettingsStore editorSettings;
		private bool loadingSettings;
		private bool editorPreferencesDirty;
		private bool splashDirty;

		private TabControl settingsTabs;
		private Label statusLabel;

		private CheckBox simpleLevelCheckBox;
		private CheckBox realTimeAudioCheckBox;
		private NumericUpDown editorVolumeNumeric;

		private ComboBox flightCameraCombo;
		private CheckBox startRealtimeCheckBox;
		private CheckBox linkedOrthographicCheckBox;
		private CheckBox showFlagsShortcutCheckBox;
		private CheckBox viewportHoverCheckBox;
		private CheckBox updateCameraFromPivCheckBox;

		private CheckBox autosaveCheckBox;
		private CheckBox autosaveMapsCheckBox;
		private CheckBox autosaveContentCheckBox;
		private ComboBox autosaveIntervalCombo;
		private NumericUpDown undoBufferNumeric;
		private CheckBox promptForCheckoutCheckBox;
		private CheckBox sourceControlCheckBox;
		private CheckBox autoAddFilesCheckBox;

		private RadioButton defaultRadio;
		private RadioButton customRadio;
		private TextBox customImageTextBox;
		private Button browseButton;
		private PictureBox preview;
		private Label sourceLabel;

		public EditorSettingsForm( string workspaceRoot )
		{
			splashSettings = new SplashSettingsStore( workspaceRoot );
			editorSettings = new EditorUserSettingsStore( workspaceRoot );
			InitializeComponent();
			LoadSettings();
		}

		protected override void Dispose( bool disposing )
		{
			if( disposing && preview != null && preview.Image != null )
			{
				preview.Image.Dispose();
				preview.Image = null;
			}
			base.Dispose( disposing );
		}

		private void InitializeComponent()
		{
			Text = "Editor Settings — UTGame";
			StartPosition = FormStartPosition.CenterParent;
			ClientSize = new Size( 860, 600 );
			FormBorderStyle = FormBorderStyle.FixedDialog;
			MaximizeBox = false;
			MinimizeBox = false;
			ShowInTaskbar = false;
			BackColor = Color.FromArgb( 35, 40, 45 );
			ForeColor = Color.FromArgb( 233, 229, 220 );
			Font = new Font( "Segoe UI", 9.0f );

			Label title = new Label();
			title.AutoSize = true;
			title.Font = new Font( "Georgia", 17.0f );
			title.ForeColor = Color.FromArgb( 247, 241, 229 );
			title.Location = new Point( 20, 17 );
			title.Text = "Editor Settings";
			Controls.Add( title );

			Label subtitle = new Label();
			subtitle.AutoSize = true;
			subtitle.ForeColor = Color.FromArgb( 227, 145, 56 );
			subtitle.Font = new Font( Font, FontStyle.Bold );
			subtitle.Location = new Point( 23, 50 );
			subtitle.Text = "UTGAME EDITOR";
			Controls.Add( subtitle );

			Label guidance = new Label();
			guidance.AutoSize = false;
			guidance.ForeColor = Color.FromArgb( 195, 202, 204 );
			guidance.Location = new Point( 23, 75 );
			guidance.Size = new Size( 810, 31 );
			guidance.Text = "These are editor-wide preferences. Close the UE3 editor before applying changes, otherwise its shutdown may overwrite the user settings file.";
			Controls.Add( guidance );

			settingsTabs = new TabControl();
			settingsTabs.Location = new Point( 20, 114 );
			settingsTabs.Size = new Size( 820, 366 );
			settingsTabs.SelectedIndexChanged += SettingsTabChanged;
			Controls.Add( settingsTabs );

			TabPage generalPage = CreatePage( "General" );
			BuildGeneralPage( generalPage );
			settingsTabs.TabPages.Add( generalPage );

			TabPage viewportsPage = CreatePage( "Viewports" );
			BuildViewportsPage( viewportsPage );
			settingsTabs.TabPages.Add( viewportsPage );

			TabPage savingPage = CreatePage( "Saving & Source Control" );
			BuildSavingPage( savingPage );
			settingsTabs.TabPages.Add( savingPage );

			TabPage splashPage = CreatePage( "Splash & Branding" );
			BuildSplashPage( splashPage );
			settingsTabs.TabPages.Add( splashPage );

			statusLabel = new Label();
			statusLabel.AutoSize = false;
			statusLabel.ForeColor = Color.FromArgb( 185, 194, 196 );
			statusLabel.Location = new Point( 23, 493 );
			statusLabel.Size = new Size( 570, 37 );
			statusLabel.Text = "Loading editor preferences…";
			Controls.Add( statusLabel );

			Button revertButton = CreateButton( "Revert", new Point( 580, 546 ), new Size( 78, 31 ), false );
			revertButton.Click += ReloadSavedSettings;
			Controls.Add( revertButton );

			Button applyButton = CreateButton( "Apply", new Point( 666, 546 ), new Size( 78, 31 ), true );
			applyButton.Click += ApplyAllSettings;
			Controls.Add( applyButton );

			Button closeButton = CreateButton( "Close", new Point( 752, 546 ), new Size( 78, 31 ), false );
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

		private void BuildGeneralPage( TabPage page )
		{
			GroupBox startupBox = CreateGroupBox( "Startup", new Point( 14, 13 ), new Size( 770, 106 ) );
			page.Controls.Add( startupBox );

			simpleLevelCheckBox = CreateOption( "Load the simple level when the editor starts", new Point( 18, 30 ), "Writes bLoadSimpleLevelAtStartup." );
			startupBox.Controls.Add( simpleLevelCheckBox );

			Label startupNote = CreateLabel(
				"Use this as a quick, lightweight editor startup. Disable it when you prefer the editor to restore its normal startup behavior.",
				new Point( 18, 59 ), new Size( 720, 30 ), Color.FromArgb( 184, 195, 197 ) );
			startupBox.Controls.Add( startupNote );

			GroupBox audioBox = CreateGroupBox( "Editor audio", new Point( 14, 133 ), new Size( 770, 111 ) );
			page.Controls.Add( audioBox );

			realTimeAudioCheckBox = CreateOption( "Enable real-time audio in the editor", new Point( 18, 30 ), "Writes bEnableRealTimeAudio." );
			audioBox.Controls.Add( realTimeAudioCheckBox );

			Label volumeLabel = CreateLabel( "Editor volume", new Point( 18, 64 ), new Size( 90, 18 ), Color.FromArgb( 220, 222, 218 ) );
			audioBox.Controls.Add( volumeLabel );

			editorVolumeNumeric = CreateNumeric( 0.0m, 1.0m, 0.05m, 2, new Point( 112, 61 ), new Size( 94, 23 ) );
			audioBox.Controls.Add( editorVolumeNumeric );

			Label volumeNote = CreateLabel( "0 is silent; 1 is the normal editor volume.", new Point( 220, 64 ), new Size( 310, 18 ), Color.FromArgb( 184, 195, 197 ) );
			audioBox.Controls.Add( volumeNote );
		}

		private void BuildViewportsPage( TabPage page )
		{
			GroupBox cameraBox = CreateGroupBox( "Camera & realtime", new Point( 14, 13 ), new Size( 770, 128 ) );
			page.Controls.Add( cameraBox );

			Label flightLabel = CreateLabel( "Flight camera controls", new Point( 18, 30 ), new Size( 160, 18 ), Color.FromArgb( 220, 222, 218 ) );
			cameraBox.Controls.Add( flightLabel );

			flightCameraCombo = new ComboBox();
			flightCameraCombo.BackColor = Color.FromArgb( 48, 55, 61 );
			flightCameraCombo.DropDownStyle = ComboBoxStyle.DropDownList;
			flightCameraCombo.ForeColor = Color.FromArgb( 240, 237, 228 );
			flightCameraCombo.Items.AddRange( new object[]
			{
				"Always use WASD",
				"Use WASD while right mouse is held",
				"Never use WASD"
			} );
			flightCameraCombo.Location = new Point( 18, 51 );
			flightCameraCombo.Size = new Size( 265, 23 );
			flightCameraCombo.SelectedIndexChanged += EditorSettingChanged;
			cameraBox.Controls.Add( flightCameraCombo );

			startRealtimeCheckBox = CreateOption( "Start viewports in real-time mode", new Point( 320, 52 ), "Writes bStartInRealtimeMode." );
			cameraBox.Controls.Add( startRealtimeCheckBox );

			Label cameraNote = CreateLabel(
				"Camera behavior affects the editor viewport only; it does not change in-game controls.",
				new Point( 18, 92 ), new Size( 690, 18 ), Color.FromArgb( 184, 195, 197 ) );
			cameraBox.Controls.Add( cameraNote );

			GroupBox interactionBox = CreateGroupBox( "Viewport interaction", new Point( 14, 154 ), new Size( 770, 158 ) );
			page.Controls.Add( interactionBox );

			linkedOrthographicCheckBox = CreateOption( "Link orthographic viewports", new Point( 18, 30 ), "Writes bUseLinkedOrthographicViewports." );
			interactionBox.Controls.Add( linkedOrthographicCheckBox );

			showFlagsShortcutCheckBox = CreateOption( "Enable show-flags shortcut", new Point( 18, 61 ), "Writes bEnableShowFlagsShortcut." );
			interactionBox.Controls.Add( showFlagsShortcutCheckBox );

			viewportHoverCheckBox = CreateOption( "Enable viewport hover feedback", new Point( 320, 30 ), "Writes bEnableViewportHoverFeedback." );
			interactionBox.Controls.Add( viewportHoverCheckBox );

			updateCameraFromPivCheckBox = CreateOption( "Update camera after Play in Viewport", new Point( 320, 61 ), "Writes bEnableViewportCameraToUpdateFromPIV." );
			interactionBox.Controls.Add( updateCameraFromPivCheckBox );

			Label interactionNote = CreateLabel(
				"These map directly to the legacy UnrealEd settings already used by this build.",
				new Point( 18, 112 ), new Size( 690, 18 ), Color.FromArgb( 184, 195, 197 ) );
			interactionBox.Controls.Add( interactionNote );
		}

		private void BuildSavingPage( TabPage page )
		{
			GroupBox autosaveBox = CreateGroupBox( "Autosave", new Point( 14, 13 ), new Size( 770, 142 ) );
			page.Controls.Add( autosaveBox );

			autosaveCheckBox = CreateOption( "Enable autosave", new Point( 18, 30 ), "Writes bAutoSaveEnable." );
			autosaveCheckBox.CheckedChanged += AutosaveChanged;
			autosaveBox.Controls.Add( autosaveCheckBox );

			autosaveMapsCheckBox = CreateOption( "Save maps", new Point( 165, 30 ), "Writes bAutoSaveMaps." );
			autosaveBox.Controls.Add( autosaveMapsCheckBox );

			autosaveContentCheckBox = CreateOption( "Save content", new Point( 280, 30 ), "Writes bAutoSaveContent." );
			autosaveBox.Controls.Add( autosaveContentCheckBox );

			Label intervalLabel = CreateLabel( "Interval (minutes)", new Point( 18, 68 ), new Size( 115, 18 ), Color.FromArgb( 220, 222, 218 ) );
			autosaveBox.Controls.Add( intervalLabel );

			autosaveIntervalCombo = new ComboBox();
			autosaveIntervalCombo.BackColor = Color.FromArgb( 48, 55, 61 );
			autosaveIntervalCombo.DropDownStyle = ComboBoxStyle.DropDownList;
			autosaveIntervalCombo.ForeColor = Color.FromArgb( 240, 237, 228 );
			autosaveIntervalCombo.Items.AddRange( new object[] { 1, 5, 10, 15, 30 } );
			autosaveIntervalCombo.Location = new Point( 137, 65 );
			autosaveIntervalCombo.Size = new Size( 76, 23 );
			autosaveIntervalCombo.SelectedIndexChanged += EditorSettingChanged;
			autosaveBox.Controls.Add( autosaveIntervalCombo );

			Label autosaveNote = CreateLabel(
				"Autosave settings use the same choices exposed by the original editor preferences.",
				new Point( 18, 107 ), new Size( 690, 18 ), Color.FromArgb( 184, 195, 197 ) );
			autosaveBox.Controls.Add( autosaveNote );

			GroupBox sourceControlBox = CreateGroupBox( "Undo & source control", new Point( 14, 169 ), new Size( 770, 143 ) );
			page.Controls.Add( sourceControlBox );

			Label undoLabel = CreateLabel( "Undo buffer (MB)", new Point( 18, 30 ), new Size( 110, 18 ), Color.FromArgb( 220, 222, 218 ) );
			sourceControlBox.Controls.Add( undoLabel );

			undoBufferNumeric = CreateNumeric( 1.0m, 256.0m, 1.0m, 0, new Point( 132, 27 ), new Size( 78, 23 ) );
			sourceControlBox.Controls.Add( undoBufferNumeric );

			promptForCheckoutCheckBox = CreateOption( "Prompt before modifying checked-out packages", new Point( 18, 65 ), "Writes bPromptForCheckoutOnPackageModification." );
			sourceControlBox.Controls.Add( promptForCheckoutCheckBox );

			sourceControlCheckBox = CreateOption( "Enable source control integration", new Point( 380, 30 ), "Writes SourceControl Disabled." );
			sourceControlBox.Controls.Add( sourceControlCheckBox );

			autoAddFilesCheckBox = CreateOption( "Automatically add new files", new Point( 380, 65 ), "Writes SourceControl AutoAddNewFiles." );
			sourceControlBox.Controls.Add( autoAddFilesCheckBox );

			Label sourceControlNote = CreateLabel(
				"The editor's selected provider remains separate; these controls preserve its legacy user settings.",
				new Point( 18, 109 ), new Size( 690, 18 ), Color.FromArgb( 184, 195, 197 ) );
			sourceControlBox.Controls.Add( sourceControlNote );
		}

		private void BuildSplashPage( TabPage page )
		{
			GroupBox modeBox = CreateGroupBox( "Startup splash", new Point( 14, 13 ), new Size( 390, 223 ) );
			page.Controls.Add( modeBox );

			defaultRadio = CreateSplashModeRadio( "Default UE3", "Use the supplied Unreal Engine 3.0 artwork.", 23 );
			customRadio = CreateSplashModeRadio( "Custom image", "Import your own 650 × 375, 24-bit BMP.", 68 );
			defaultRadio.CheckedChanged += SplashModeChanged;
			customRadio.CheckedChanged += SplashModeChanged;
			modeBox.Controls.Add( defaultRadio );
			modeBox.Controls.Add( customRadio );

			Label customImageLabel = CreateLabel( "Custom BMP", new Point( 18, 120 ), new Size( 85, 18 ), Color.FromArgb( 214, 218, 218 ) );
			modeBox.Controls.Add( customImageLabel );

			customImageTextBox = new TextBox();
			customImageTextBox.BackColor = Color.FromArgb( 48, 55, 61 );
			customImageTextBox.ForeColor = Color.FromArgb( 240, 237, 228 );
			customImageTextBox.Location = new Point( 18, 141 );
			customImageTextBox.Size = new Size( 284, 23 );
			customImageTextBox.TextChanged += CustomImageChanged;
			modeBox.Controls.Add( customImageTextBox );

			browseButton = CreateButton( "Browse", new Point( 310, 139 ), new Size( 63, 27 ), false );
			browseButton.Click += BrowseForCustomImage;
			modeBox.Controls.Add( browseButton );

			preview = new PictureBox();
			preview.BackColor = Color.FromArgb( 16, 19, 22 );
			preview.BorderStyle = BorderStyle.FixedSingle;
			preview.Location = new Point( 421, 13 );
			preview.Size = new Size( 362, 208 );
			preview.SizeMode = PictureBoxSizeMode.Zoom;
			page.Controls.Add( preview );

			sourceLabel = CreateLabel( String.Empty, new Point( 421, 229 ), new Size( 362, 45 ), Color.FromArgb( 185, 194, 196 ) );
			page.Controls.Add( sourceLabel );

			Label safeArea = CreateLabel(
				"Keep the lower 44 pixels clear for editor startup text and the lower 26 pixels clear for game copyright text.",
				new Point( 14, 277 ), new Size( 770, 20 ), Color.FromArgb( 185, 194, 196 ) );
			page.Controls.Add( safeArea );

			Button applySplashButton = CreateButton( "Apply Selected Splash", new Point( 14, 304 ), new Size( 156, 29 ), true );
			applySplashButton.Click += ApplySelectedSplash;
			page.Controls.Add( applySplashButton );
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
			option.CheckedChanged += EditorSettingChanged;
			ToolTip tip = new ToolTip();
			tip.SetToolTip( option, tooltip );
			return option;
		}

		private NumericUpDown CreateNumeric( decimal minimum, decimal maximum, decimal increment, int decimalPlaces, Point location, Size size )
		{
			NumericUpDown numeric = new NumericUpDown();
			numeric.BackColor = Color.FromArgb( 48, 55, 61 );
			numeric.DecimalPlaces = decimalPlaces;
			numeric.ForeColor = Color.FromArgb( 240, 237, 228 );
			numeric.Increment = increment;
			numeric.Location = location;
			numeric.Maximum = maximum;
			numeric.Minimum = minimum;
			numeric.Size = size;
			numeric.ValueChanged += EditorSettingChanged;
			return numeric;
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

		private RadioButton CreateSplashModeRadio( string title, string details, int top )
		{
			RadioButton radio = new RadioButton();
			radio.AutoSize = false;
			radio.ForeColor = Color.FromArgb( 235, 232, 223 );
			radio.Location = new Point( 18, top );
			radio.Size = new Size( 355, 42 );
			radio.Text = title + Environment.NewLine + "    " + details;
			return radio;
		}

		private void LoadSettings()
		{
			loadingSettings = true;
			try
			{
				EditorUserSettingsData settings = editorSettings.Load();
				simpleLevelCheckBox.Checked = settings.LoadSimpleLevelAtStartup;
				realTimeAudioCheckBox.Checked = settings.EnableRealTimeAudio;
				editorVolumeNumeric.Value = settings.EditorVolumeLevel;
				SelectFlightCameraMode( settings.FlightCameraControlType );
				startRealtimeCheckBox.Checked = settings.StartInRealtimeMode;
				linkedOrthographicCheckBox.Checked = settings.UseLinkedOrthographicViewports;
				showFlagsShortcutCheckBox.Checked = settings.EnableShowFlagsShortcut;
				viewportHoverCheckBox.Checked = settings.EnableViewportHoverFeedback;
				updateCameraFromPivCheckBox.Checked = settings.EnableViewportCameraToUpdateFromPiv;
				autosaveCheckBox.Checked = settings.AutoSaveEnabled;
				autosaveMapsCheckBox.Checked = settings.AutoSaveMaps;
				autosaveContentCheckBox.Checked = settings.AutoSaveContent;
				SelectAutosaveInterval( settings.AutoSaveTimeMinutes );
				undoBufferNumeric.Value = settings.UndoBufferSize;
				promptForCheckoutCheckBox.Checked = settings.PromptForCheckout;
				sourceControlCheckBox.Checked = settings.SourceControlEnabled;
				autoAddFilesCheckBox.Checked = settings.AutoAddNewFiles;
				LoadSplashSelection();
				UpdateAutosaveControls();
				editorPreferencesDirty = false;
				splashDirty = false;
				statusLabel.ForeColor = Color.FromArgb( 185, 194, 196 );
				statusLabel.Text = "Loaded editor preferences. Nothing has been changed on disk.";
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

		private void LoadSplashSelection()
		{
			SplashSelection selection = splashSettings.Load();
			customImageTextBox.Text = selection.CustomImagePath ?? String.Empty;
			switch( selection.Mode )
			{
				case SplashMode.Custom:
					customRadio.Checked = true;
					break;
				default:
					defaultRadio.Checked = true;
					break;
			}
			UpdateSplashPresentation();
		}

		private void SelectFlightCameraMode( string mode )
		{
			if( String.Equals( mode, "WASD_RMBOnly", StringComparison.OrdinalIgnoreCase ) )
			{
				flightCameraCombo.SelectedIndex = 1;
			}
			else if( String.Equals( mode, "WASD_Never", StringComparison.OrdinalIgnoreCase ) )
			{
				flightCameraCombo.SelectedIndex = 2;
			}
			else
			{
				flightCameraCombo.SelectedIndex = 0;
			}
		}

		private string GetFlightCameraMode()
		{
			switch( flightCameraCombo.SelectedIndex )
			{
				case 1: return "WASD_RMBOnly";
				case 2: return "WASD_Never";
				default: return "WASD_Always";
			}
		}

		private void SelectAutosaveInterval( int minutes )
		{
			int index = autosaveIntervalCombo.Items.IndexOf( minutes );
			autosaveIntervalCombo.SelectedIndex = index >= 0 ? index : 2;
		}

		private void AutosaveChanged( object sender, EventArgs eventArgs )
		{
			UpdateAutosaveControls();
			EditorSettingChanged( sender, eventArgs );
		}

		private void UpdateAutosaveControls()
		{
			bool enabled = autosaveCheckBox.Checked;
			autosaveMapsCheckBox.Enabled = enabled;
			autosaveContentCheckBox.Enabled = enabled;
			autosaveIntervalCombo.Enabled = enabled;
		}

		private void EditorSettingChanged( object sender, EventArgs eventArgs )
		{
			if( !loadingSettings )
			{
				editorPreferencesDirty = true;
				if( statusLabel != null )
				{
					statusLabel.ForeColor = Color.FromArgb( 227, 183, 99 );
					statusLabel.Text = "Unsaved editor preferences. Click Apply after closing the UE3 editor.";
				}
			}
		}

		private void SettingsTabChanged( object sender, EventArgs eventArgs )
		{
			if( !loadingSettings && statusLabel != null && !editorPreferencesDirty && !splashDirty )
			{
				statusLabel.ForeColor = Color.FromArgb( 185, 194, 196 );
				statusLabel.Text = settingsTabs.SelectedTab.Text + " contains editor-wide preferences, separate from Project Settings.";
			}
		}

		private void SplashModeChanged( object sender, EventArgs eventArgs )
		{
			RadioButton radio = sender as RadioButton;
			if( radio != null && radio.Checked )
			{
				if( !loadingSettings )
				{
					splashDirty = true;
					SetUnsavedSplashStatus();
				}
				UpdateSplashPresentation();
			}
		}

		private void CustomImageChanged( object sender, EventArgs eventArgs )
		{
			if( customRadio.Checked )
			{
				if( !loadingSettings )
				{
					splashDirty = true;
					SetUnsavedSplashStatus();
				}
				UpdateSplashPresentation();
			}
		}

		private void SetUnsavedSplashStatus()
		{
			if( statusLabel != null )
			{
				statusLabel.ForeColor = Color.FromArgb( 227, 183, 99 );
				statusLabel.Text = "Unsaved splash change. Apply it here or use the main Apply button.";
			}
		}

		private void BrowseForCustomImage( object sender, EventArgs eventArgs )
		{
			using( OpenFileDialog dialog = new OpenFileDialog() )
			{
				dialog.Filter = "Bitmap files (*.bmp)|*.bmp";
				dialog.Multiselect = false;
				dialog.Title = "Choose a 650 × 375, 24-bit bitmap";
				if( dialog.ShowDialog( this ) == DialogResult.OK )
				{
					customRadio.Checked = true;
					customImageTextBox.Text = dialog.FileName;
				}
			}
		}

		private void ApplyAllSettings( object sender, EventArgs eventArgs )
		{
			try
			{
				bool savedEditorPreferences = false;
				bool appliedSplash = false;
				if( editorPreferencesDirty )
				{
					editorSettings.Save( CreateEditorSettingsData() );
					editorPreferencesDirty = false;
					savedEditorPreferences = true;
				}
				if( splashDirty )
				{
					ApplySplashSelection();
					appliedSplash = true;
				}

				statusLabel.ForeColor = Color.FromArgb( 166, 213, 137 );
				if( savedEditorPreferences || appliedSplash )
				{
					statusLabel.Text = "Saved. Restart the editor before its next use so it reads the updated settings.";
				}
				else
				{
					statusLabel.Text = "There are no pending changes.";
				}
			}
			catch( Exception error )
			{
				statusLabel.ForeColor = Color.FromArgb( 239, 139, 126 );
				statusLabel.Text = error.Message;
			}
		}

		private void ApplySelectedSplash( object sender, EventArgs eventArgs )
		{
			try
			{
				ApplySplashSelection();
				statusLabel.ForeColor = Color.FromArgb( 166, 213, 137 );
				statusLabel.Text = "Saved. The selected splash will appear the next time the editor or game starts.";
			}
			catch( Exception error )
			{
				statusLabel.ForeColor = Color.FromArgb( 239, 139, 126 );
				statusLabel.Text = error.Message;
			}
		}

		private void ApplySplashSelection()
		{
			splashSettings.Apply( GetSelectedSplashMode(), customImageTextBox.Text );
			splashDirty = false;
		}

		private EditorUserSettingsData CreateEditorSettingsData()
		{
			EditorUserSettingsData settings = new EditorUserSettingsData();
			settings.LoadSimpleLevelAtStartup = simpleLevelCheckBox.Checked;
			settings.EnableRealTimeAudio = realTimeAudioCheckBox.Checked;
			settings.EditorVolumeLevel = editorVolumeNumeric.Value;
			settings.FlightCameraControlType = GetFlightCameraMode();
			settings.StartInRealtimeMode = startRealtimeCheckBox.Checked;
			settings.UseLinkedOrthographicViewports = linkedOrthographicCheckBox.Checked;
			settings.EnableShowFlagsShortcut = showFlagsShortcutCheckBox.Checked;
			settings.EnableViewportHoverFeedback = viewportHoverCheckBox.Checked;
			settings.EnableViewportCameraToUpdateFromPiv = updateCameraFromPivCheckBox.Checked;
			settings.AutoSaveEnabled = autosaveCheckBox.Checked;
			settings.AutoSaveMaps = autosaveMapsCheckBox.Checked;
			settings.AutoSaveContent = autosaveContentCheckBox.Checked;
			settings.AutoSaveTimeMinutes = autosaveIntervalCombo.SelectedItem == null ? 10 : (int)autosaveIntervalCombo.SelectedItem;
			settings.UndoBufferSize = Decimal.ToInt32( undoBufferNumeric.Value );
			settings.PromptForCheckout = promptForCheckoutCheckBox.Checked;
			settings.SourceControlEnabled = sourceControlCheckBox.Checked;
			settings.AutoAddNewFiles = autoAddFilesCheckBox.Checked;
			return settings;
		}

		private void ReloadSavedSettings( object sender, EventArgs eventArgs )
		{
			LoadSettings();
		}

		private SplashMode GetSelectedSplashMode()
		{
			if( customRadio.Checked )
			{
				return SplashMode.Custom;
			}
			return SplashMode.Default;
		}

		private void UpdateSplashPresentation()
		{
			SplashMode mode = GetSelectedSplashMode();
			bool isCustom = mode == SplashMode.Custom;
			customImageTextBox.Enabled = isCustom;
			browseButton.Enabled = isCustom;

			string previewPath = splashSettings.GetEditorSourcePath( mode, customImageTextBox.Text );
			LoadPreview( previewPath );

			if( mode == SplashMode.Default )
			{
				sourceLabel.Text = "Default preset\r\nUses the supplied Unreal Engine 3.0 artwork from Binaries\\Splash.";
			}
			else
			{
				sourceLabel.Text = "Custom preset\r\nThe selected BMP is copied into UTGame\\Splash\\PC for both startup routes.";
			}
		}

		private void LoadPreview( string imagePath )
		{
			Image oldImage = preview.Image;
			preview.Image = null;
			if( oldImage != null )
			{
				oldImage.Dispose();
			}

			if( String.IsNullOrWhiteSpace( imagePath ) || !File.Exists( imagePath ) )
			{
				return;
			}

			try
			{
				using( Image image = Image.FromFile( imagePath ) )
				{
					preview.Image = new Bitmap( image );
				}
			}
			catch
			{
				// Apply performs validation and gives a specific user-facing error.
			}
		}
	}
}
