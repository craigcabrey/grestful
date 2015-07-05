/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Application.Class;

import gtk.Dialog;
import gtk.Window;
import gtk.AboutDialog;
static import gtk.Application;

import gio.Menu;
import gio.File;
import gio.SimpleAction;

import glib.KeyFile;
import glib.Variant;
import glib.VariantType;

import gsv.SourceStyleScheme;

import Application.Utility;
import Application.MainWindow.Class : MainWindow = Class;
import Application.StyleSchemeChooserDialog;

import Generic.State;
import Generic.Signal : Signal;
import Generic.Mixins.Singleton;
import Generic.StateAwareInterface;

/**
 * The class handling the application itself, which can consist of multiple windows.
 */
class Class : gtk.Application.Application, StateAwareInterface
{
    static Signal!("openFile", string) openFileRequestedSignal;

public:
    /**
     * Static constructor.
     */
    static this()
    {
        import gsv.SourceView;
        import gsv.StyleSchemeChooserWidget;

        import gobject.Type;

        GInterfaceInfo interfaceInfo = {
            null,
            null,
            null
        };

        // Needed because these aren't registered as interface, which makes GtkBuilder complain it can't find them for
        // the Glade file.
        Type.addInterfaceStatic(Type.fromName("GtkSourceView"), SourceView.getType(), &interfaceInfo);
        Type.addInterfaceStatic(Type.fromName("GtkSourceStyleSchemeChooserWidget"), StyleSchemeChooserWidget.getType(), &interfaceInfo);
    }

    /**
     * Constructor.
     */
    this()
    {
        super(APPLICATION_ID, ApplicationFlags.FLAGS_NONE);

        this.addOnActivate(&onActivate);
        this.addOnStartup(&onStartup);

        with (State.Instance)
        {
            import glib.Util;
            import std.string : toLower;

            string configDirectory = Util.buildFilename(Util.getUserConfigDir(), APPLICATION_NAME.toLower());

            ConfigDirectory = configDirectory;
            ConfigFile = Util.buildFilename(configDirectory, "state.ini");

            register(this);
        }
    }

public:
    /**
     * {@inheritDoc}.
     *
     * Realizes functionality from {@see StateAwareInterface}.
     */
    void loadState(KeyFile file, string groupName)
    {
        groupName ~= "Application";

        string styleSchemeId = file.getStringDefault(groupName, "StyleSchemeId", null);

        if (styleSchemeId)
        {
            import gsv.SourceStyleSchemeManager;

            auto scheme = SourceStyleSchemeManager.getDefault().getScheme(styleSchemeId);

            if (scheme)
                this.mainWindow.StyleScheme = scheme;
        }
    }

    /**
     * {@inheritDoc}.
     *
     * Realizes functionality from {@see StateAwareInterface}.
     */
    void saveState(KeyFile file, string groupName)
    {
        groupName ~= "Application";

        file.setString(groupName, "StyleSchemeId", this.mainWindow.StyleScheme.getId());
    }

public:
    /**
     * Retrieves the action with the specified name. The action must exist. If an attempt is made to fetch a
     * non-existing action, it is a programmatic error and it will be caught by an assert in debug mode.
     */
    SimpleAction getAction(string name)
    {
        assert(name in this.registeredActions);
        return this.registeredActions[name];
    }

    /**
     * Convenience function to quickly set an action as enabled or disabled.
     */
    void setActionEnabled(string name, bool enabled)
    {
        this.getAction(name).setEnabled(enabled);
    }

    /**
     * Adds a new action to the specified menu. An action is automatically added to the application that invokes the
     * specified callback when the actual menu item is activated.
     *
     * @param string      id                   The ID to give to the action. This can be used in other places to refer
     *                                         to the action by a string. Must always start with "app.".
     * @param string      accelerator          The (application wide) keyboard accelerator to activate the action.
     * @param delegate    callback             The callback to invoke when the action is invoked.
     * @param VariantType type                 The type of data passed as parameter to the action when activated.
     * @param Variant     acceleratorParameter The parameter to pass to the callback when the action is invoked by its
     *                                         accelerator.
     *
     * @return SimpleAction The registered action.
     */
    SimpleAction registerAction(
        string id,
        string accelerator = null,
        void delegate(Variant, SimpleAction) callback = null,
        VariantType type = null,
        Variant acceleratorParameter = null
    ) {
        // Application registered actions expect a prefix of app. and we need to specify the name
        // without 'app' here.
        SimpleAction action = new SimpleAction(id[4 .. $], type);
        this.registeredActions[id] = action;

        if (callback !is null)
            action.addOnActivate(callback);

        this.addAction(action);

        if (accelerator)
            this.addAccelerator(accelerator, id, acceleratorParameter);

        return action;
    }

private:
    /**
     * Called when the application needs to start up. This happens in all cases when the application is "started", thus
     * also when the user wants to open files with the application.
     */
    void onStartup(gio.Application.Application app)
    {
        this.installAppMenu();
    }

	/**
	 * Called when the application is activated. i.e. when it is started by normal means (without any files to open),
     * thus not when opening files through the file browser or via the command line.
	 */
	void onActivate(gio.Application.Application app)
	{
		this.mainWindow = new MainWindow(this);

        this.mainWindow.Widget.showAll();
	}

    /**
     * Shows the about dialog.
     */
    void showAboutDialog()
    {
        AboutDialog dialog;

        with (dialog = new AboutDialog())
        {
            setDestroyWithParent(true);
            setTransientFor(this.mainWindow.Widget);
            setModal(true);

            setWrapLicense(true);
            setLogoIconName(null);
            setName(APPLICATION_NAME);
            setComments(APPLICATION_COMMENTS);
            setVersion(APPLICATION_VERSION);
            setCopyright(APPLICATION_COPYRIGHT);
            setAuthors(APPLICATION_AUTHORS.dup);
            setArtists(APPLICATION_ARTISTS.dup);
            setDocumenters(APPLICATION_DOCUMENTERS.dup);
            setTranslatorCredits(APPLICATION_TRANSLATORS);
            setLicense(APPLICATION_LICENSE);
            //addCreditSection(_("Credits"), [])

            addOnResponse(delegate(int responseId, Dialog sender) {
                if (responseId == ResponseType.CANCEL || responseId == ResponseType.DELETE_EVENT)
                    sender.hideOnDelete(); // Needed to make the window closable (and hide instead of be deleted).
            });

            present();
        }
    }

	/**
	 * Installs the application menu. This is the menu that drops down in gnome-shell when you click the application
	 * name next to Activities.
	 */
	void installAppMenu()
	{
        Menu menu;

		this.registerAction("app.about", null, delegate(Variant, SimpleAction) {
			this.showAboutDialog();
		});

        this.registerAction("app.quit", null, delegate(Variant, SimpleAction) {
			this.mainWindow.Widget.close();
		});

        this.registerAction("app.select-style-scheme", null, delegate(Variant, SimpleAction) {
            auto styleSchemeChooserDialog = new StyleSchemeChooserDialog(this);

            styleSchemeChooserDialog.styleSchemeChangedSignal.listen((StyleSchemeChooserDialog, SourceStyleScheme scheme) {
                this.mainWindow.StyleScheme = scheme;

                return EventPropagation.PROPAGATE;
            });

            with (styleSchemeChooserDialog.Widget)
            {
                setTransientFor(this.mainWindow.Widget);

                present();
            }
		});

        with (menu = new Menu())
        {
            append(_("_About"), "app.about");
            append(_("_Select Style Scheme"), "app.select-style-scheme");
            append(_("_Quit"), "app.quit");
        }

		this.setAppMenu(menu);
	}

private:
	/**
	 * The main application window.
	 */
	MainWindow mainWindow;

    /**
     * Maps actions registered to the application by their action name.
     */
    SimpleAction[string] registeredActions;
}
