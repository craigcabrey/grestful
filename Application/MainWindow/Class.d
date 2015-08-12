/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Application.MainWindow.Class;

// import std.experimental.logger;

import gio.Menu;
import gio.SimpleAction;

import glib.KeyFile;

import gtk.Box;
import gtk.Entry;
import gtk.Stack;
import gtk.Paned;
import gtk.Label;
import gtk.Button;
import gtk.InfoBar;
import gtk.Popover;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeStore;
import gtk.ListStore;
import gtk.EditableIF;
import gtk.ProgressBar;
import gtk.ComboBoxText;
import gtk.TreeModelSort;
import gtk.TreeViewColumn;
import gtk.CellRendererText;
import gtk.ApplicationWindow;

import gsv.SourceView;
import gsv.SourceLanguage;
import gsv.SourceStyleScheme;
import gsv.SourceLanguageManager;

import Generic.State;
import Generic.Request;
import Generic.StateAwareInterface;
import Generic.Buildable : Buildable;

import Application.Class : ApplicationClass = Class;
import Application.Utility;
import Application.RequestSerializer;

import Application.MainWindow.RequestsTree : RequestsTree;

/**
 * The main application window.
 */
class Class : Buildable!ApplicationWindow, StateAwareInterface
{
public:
    /**
     * Constructor.
     *
     * @param application Application instance.
     */
    this(ApplicationClass application)
    {
        super(APPLICATION_DESIGN_DIR ~ "MainWindow.glade", "mainWindow");

        State.Instance.register(this);

        this.Widget.setShowMenubar(false);
        this.Widget.setApplication(application);
        this.Widget.setTitle(APPLICATION_NAME);
        //this.Widget.setDefaultIconFromFile(APPLICATION_RESOURCE_DIR ~ "Logo.png");

        this.setupLayout();
        this.connectHandlers();
    }

public:
    @property
    {
        /**
         * Retrieves the active style scheme used by the response and result source views.
         *
         * @return The style scheme.
         */
        SourceStyleScheme StyleScheme()
        {
            auto dataSourceView = this.getWidget!SourceView("dataSourceView");

            return dataSourceView.getBuffer().getStyleScheme();
        }

        /**
         * Sets the style scheme to use for the response and result source views.
         *
         * @param scheme The scheme to use.
         */
        void StyleScheme(SourceStyleScheme scheme)
        {
            auto dataSourceView = this.getWidget!SourceView("dataSourceView");
            auto outputSourceView = this.getWidget!SourceView("outputSourceView");

            dataSourceView.getBuffer().setStyleScheme(scheme);
            outputSourceView.getBuffer().setStyleScheme(scheme);
        }
    }

public:
    /**
     * @copydoc StateAwareInterface::loadState()
     */
    void loadState(KeyFile file, string groupName)
    {
        auto serializer = new RequestSerializer(file);

        void loadRequestInner(KeyFile file, string groupName, TreeIter parent)
        {
            ulong requestCount = file.getIntegerDefault(groupName, "ChildrenCount", 0);

            foreach (i; 1 .. (requestCount + 1))
            {
                string nestedGroupName = groupName ~ to!string(i);

                auto request = this.createRequest();

                serializer.unserialize(request, nestedGroupName);

                this.savedRequests ~= request;

                auto iter = this.requestsTree.addNode(
                    file.getStringDefault(nestedGroupName, "Name", ""),
                    to!string(request.HttpMethod),
                    cast(int) (this.savedRequests.length - 1),
                    parent
                );

                loadRequestInner(file, nestedGroupName, iter);
            }
        }

        loadRequestInner(file, "Request", null);

        // Restore the last selected languages for the source views.
        groupName ~= "MainWindow";

        auto dataLanguageId = file.getStringDefault(groupName, "DataLanguageId", null);

        if (dataLanguageId)
        {
            auto language = SourceLanguageManager.getDefault().getLanguage(dataLanguageId);

            if (language)
                this.getWidget!SourceView("dataSourceView").getBuffer().setLanguage(language);
        }

        auto outputLanguageId = file.getStringDefault(groupName, "OutputLanguageId", null);

        if (outputLanguageId)
        {
            auto language = SourceLanguageManager.getDefault().getLanguage(outputLanguageId);

            if (language)
                this.getWidget!SourceView("outputSourceView").getBuffer().setLanguage(language);
        }
    }

    /**
     * @copydoc StateAwareInterface::saveState()
     */
    void saveState(KeyFile file, string groupName)
    {
        auto serializer = new RequestSerializer(file);
        auto requestsTreeStore = this.requestsTree.Store;

        void saveRequestInner(KeyFile file, string groupName, TreeIter parent)
        {
            auto iter = new TreeIter();
            iter.setModel(requestsTreeStore);

            file.setInteger(groupName, "ChildrenCount", requestsTreeStore.iterNChildren(parent));

            ulong i = 1;

            if (requestsTreeStore.iterChildren(iter, parent))
            {
                do
                {
                    string name  = requestsTreeStore.getValueString(iter, 0);
                    int    index = requestsTreeStore.getValueInt(iter, 1);

                    assert(index < this.savedRequests.length);

                    auto request = this.savedRequests[index];

                    string nestedGroupName = groupName ~ to!string(i);

                    serializer.serialize(request, name, nestedGroupName);

                    saveRequestInner(file, nestedGroupName, iter);

                    ++i;

                } while (requestsTreeStore.iterNext(iter));
            }
        }

        saveRequestInner(file, "Request", null);

        // Save the last selected languages for the source views.
        groupName ~= "MainWindow";

        auto dataSourceView = this.getWidget!SourceView("dataSourceView");
        auto outputSourceView = this.getWidget!SourceView("outputSourceView");

        auto dataLanguage = dataSourceView.getBuffer().getLanguage();
        auto outputLanguage = outputSourceView.getBuffer().getLanguage();

        if (dataLanguage)
            file.setString(groupName, "DataLanguageId", dataLanguage.getId());

        if (outputLanguage)
            file.setString(groupName, "OutputLanguageId", outputLanguage.getId());
    }

protected:
    /**
     * Reconfigures the layout to contain widgets that can't be easily added via the builder description file (i.e.
     * Glade).
     */
    void setupLayout()
    {
        this.requestsTree = new RequestsTree(this.Builder, "requestsTreeView");

        // Ensure that we have the proper sorting column set up for the response header list.
        auto responseHeadersSortedListStore = this.getObject!TreeModelSort("responseHeadersSortedListStore");

        responseHeadersSortedListStore.setSortColumnId(0, SortType.ASCENDING);

        this.setupInfoBar();
        this.setupPopovers();
        this.setupMethodCombobox();

        this.setupCssStyling();
    }

    /**
     * Sets up and applies CSS styling.
     */
    void setupCssStyling()
    {
        import gdk.Screen;
        import gtk.CssProvider;
        import gtk.StyleContext;

        auto cssProvider = new CssProvider();
        cssProvider.loadFromData("
            /*
                Button collection is a class for a widget wrapping a list of buttons that makes the buttons seemingly
                stick together by replacing the double border between them with a single border.
            */
            .button-collection > .button:not(:last-child) {
                border-right: 0;
                border-top-right-radius: 0;
                border-bottom-right-radius: 0;
            }

            .button-collection > .button:not(:first-child) {
                border-top-left-radius: 0;
                border-bottom-left-radius: 0;
            }
        ");

        auto styleContext = this.Widget.getStyleContext();
        styleContext.addProviderForScreen(Screen.getDefault(), cssProvider, StyleProviderPriority.APPLICATION);
        //styleContext.save();
    }

    /**
     * Fills in the items of the request method combobox with values from our enum.
     */
    void setupMethodCombobox()
    {
        auto methodComboBox = this.getWidget!ComboBoxText("methodComboBox");

        foreach (method; __traits(allMembers, Request.Method))
            methodComboBox.append(method, method);

        methodComboBox.setActiveText(__traits(allMembers, Request.Method)[0]);
    }

    /**
     * Set up the infobar.
     */
    void setupInfoBar()
    {
        auto infoBar = this.getWidget!InfoBar("infoBar");

        infoBar.addOnResponse((int responseId, InfoBar sender) {
            if (responseId == ResponseType.CLOSE)
    			sender.hide();
        });

        infoBar.showAll(); // NOTE: The widget itself has "no show all" set, so this will not actually show it.
    }

    /**
     * Creates and sets up popovers.
     */
    void setupPopovers()
    {
        auto app = this.Widget.getApplication();

        immutable string plainTextValue = "plain-text";

        immutable string[string] supportedLanguages = [
            "Plain Text" : plainTextValue,
            "XML"        : "xml",
            "JSON"       : "json"
        ];

        with (this.selectRequestDataLanguagePopover = new Popover(this.getWidget("dataSourceViewSelectLanguageButton")))
        {
            auto model = new Menu();

            immutable string actionNamespace = "request-body-language";

            foreach (name, value; supportedLanguages)
            {
                string actionName = actionNamespace;
                actionName ~= ".";
                actionName ~= value;

                auto action = new SimpleAction(actionName, null);

                action.addOnActivate((Variant, SimpleAction sender) {
                    auto sourceLanguageManager = SourceLanguageManager.getDefault();
                    auto dataSourceView = this.getWidget!SourceView("dataSourceView");

                    auto language = value != plainTextValue ? sourceLanguageManager.getLanguage(value) : null;
                    dataSourceView.getBuffer().setLanguage(language);
                });

                app.addAction(action);

                model.append(name, value);
            }

            bindModel(model, "app." ~ actionNamespace);
        }

        with (this.selectResponseOutputLanguagePopover = new Popover(this.getWidget("outputSourceViewSelectLanguageButton")))
        {
            auto model = new Menu();

            immutable string actionNamespace = "response-output-language";

            foreach (name, value; supportedLanguages)
            {
                string actionName = actionNamespace;
                actionName ~= ".";
                actionName ~= value;

                auto action = new SimpleAction(actionName, null);

                action.addOnActivate((Variant, SimpleAction sender) {
                    auto sourceLanguageManager = SourceLanguageManager.getDefault();
                    auto outputSourceView = this.getWidget!SourceView("outputSourceView");

                    auto language = value != plainTextValue ? sourceLanguageManager.getLanguage(value) : null;
                    outputSourceView.getBuffer().setLanguage(language);
                });

                app.addAction(action);

                model.append(name, value);
            }

            bindModel(model, "app." ~ actionNamespace);
        }

        with (this.addNewRequestPopover = new Popover(this.getWidget("saveNewRequestButton")))
        {
            add(this.getWidget("addNewRequestPopoverBox"));
        }

        with (this.addRequestHeaderPopover = new Popover(this.getWidget("addRequestHeaderButton")))
        {
            add(this.getWidget("addRequestHeaderPopoverBox"));
        }

        with (this.authenticationHeaderPopover = new Popover(this.getWidget("generateAuthenticationHeaderButton")))
        {
            add(this.getWidget("authenticationHeaderPopoverBox"));
        }
    }

    /**
     * Connects signal/event handlers for widgets.
     */
    void connectHandlers()
    {
        this.connectMainHandlers();
        this.connectAddRequestHandlers();
        this.connectRequestDataHandlers();
        this.connectRequestsTreeHandlers();
        this.connectResponseOutputHandlers();
        this.connectRequestHeadersHandlers();
        this.connectAddRequestHeaderHandlers();
        this.connectGenerateAuthenticationHeaderHandlers();

        this.getWidget!Button("sendButton").addOnClicked((Button) { this.sendRequest(); });
        this.getWidget!Button("cancelButton").addOnClicked((Button) { this.cancelRequest(); });
    }

    /**
     * Connects handlers related to adding and saving requests.
     */
    void connectAddRequestHandlers()
    {
        auto saveRequestButton = this.getWidget!Button("saveRequestButton");
        auto newRequestNameEntry = this.getWidget!Entry("newRequestNameEntry");
        auto saveNewRequestButton = this.getWidget!Button("saveNewRequestButton");
        auto confirmAddNewRequestButton = this.getWidget!Button("confirmAddNewRequestButton");

        saveRequestButton.addOnClicked((Button) {
            this.saveActiveRequest();
        });

        saveNewRequestButton.addOnClicked((Button) {
            // Needed to make pressing the return key in one of the input fields trigger the button.
            confirmAddNewRequestButton.grabDefault();

            this.addNewRequestPopover.showAll();
        });

        newRequestNameEntry.addOnChanged((EditableIF sender) {
            bool hasText = (cast(Entry) sender).getText().length > 0;

            confirmAddNewRequestButton.setSensitive(hasText);
        });

        confirmAddNewRequestButton.addOnClicked((Button) {
            string name = newRequestNameEntry.getText();

            if (name.length > 0)
            {
                this.saveCurrentRequestAsNew(name);
                this.addNewRequestPopover.hide();
            }
        });
    }

    /**
     * Connects handlers for the generate authentication header button and widgets.
     */
    void connectGenerateAuthenticationHeaderHandlers()
    {
        auto authenticationHeaderUserEntry = this.getWidget!Entry("authenticationHeaderUserEntry");
        auto authenticationHeaderPasswordEntry = this.getWidget!Entry("authenticationHeaderPasswordEntry");
        auto generateAuthenticationHeaderButton = this.getWidget!Button("generateAuthenticationHeaderButton");
        auto confirmGenerateAuthenticationHeaderButton = this.getWidget!Button("confirmGenerateAuthenticationHeaderButton");

        generateAuthenticationHeaderButton.addOnClicked((Button) {
            // See also connectAddRequestHandlers for why this is needed.
            confirmGenerateAuthenticationHeaderButton.grabDefault();

            this.authenticationHeaderPopover.showAll();
        });

        authenticationHeaderUserEntry.addOnChanged((EditableIF sender) {
            bool hasText = (cast(Entry) sender).getText().length > 0;

            confirmGenerateAuthenticationHeaderButton.setSensitive(hasText);
        });

        confirmGenerateAuthenticationHeaderButton.addOnClicked((Button) {
            string username = authenticationHeaderUserEntry.getText();
            string password = authenticationHeaderPasswordEntry.getText();

            if (username.length > 0)
            {
                this.addBasicAuthenticationHeader(username, password);
                this.authenticationHeaderPopover.hide();
            }
        });
    }

    /**
     * Connects handlers for the add request header button and widgets.
     */
    void connectAddRequestHeaderHandlers()
    {
        auto requestHeaderNameEntry = this.getWidget!Entry("requestHeaderNameEntry");
        auto requestHeaderValueEntry = this.getWidget!Entry("requestHeaderValueEntry");
        auto addRequestHeaderButton = this.getWidget!Button("addRequestHeaderButton");
        auto confirmAddNewRequestHeaderButton = this.getWidget!Button("confirmAddNewRequestHeaderButton");

        addRequestHeaderButton.addOnClicked((Button) {
            // See also connectAddRequestHandlers for why this is needed.
            confirmAddNewRequestHeaderButton.grabDefault();

            this.addRequestHeaderPopover.showAll();
        });

        requestHeaderNameEntry.addOnChanged((EditableIF sender) {
            bool hasText = (cast(Entry) sender).getText().length > 0;

            confirmAddNewRequestHeaderButton.setSensitive(hasText);
        });

        confirmAddNewRequestHeaderButton.addOnClicked((Button) {
            string name = requestHeaderNameEntry.getText();
            string value = requestHeaderValueEntry.getText();

            if (name.length > 0)
            {
                this.addRequestHeaderRow(name, value);
                this.addRequestHeaderPopover.hide();
            }
        });
    }

    /**
     * Connect handlers related to the requests tree.
     */
    void connectRequestsTreeHandlers()
    {
        this.requestsTree.deleteRequestedSignal.listen(&this.onRequestDeleted);
        this.requestsTree.activateRequestedSignal.listen(&this.onRequestActivated);
    }

    /**
     * Connect handlers related to the request headers tree.
     */
    void connectRequestHeadersHandlers()
    {
        auto removeRequestHeaderButton = this.getWidget!Button("removeRequestHeaderButton");

        // Connect editing handlers that just confirm the new text the user tried to enter.
        auto requestHeadersListStore = this.getObject!ListStore("requestHeadersListStore");

        auto requestsNameRendererText = this.getObject!CellRendererText("requestsNameRendererText");
        auto requestHeadersNameRendererText = this.getObject!CellRendererText("requestHeadersNameRendererText");
        auto requestHeadersValueRendererText = this.getObject!CellRendererText("requestHeadersValueRendererText");

        void applyUserEnteredText(string storeName, int column)(string pathString, string newText, CellRendererText renderer)
        {
            auto store = mixin(storeName);

            TreePath iterPath = new TreePath(pathString);
            TreeIter iter = new TreeIter(store, iterPath);

            store.setValue(iter, column, newText);
        }

        removeRequestHeaderButton.addOnClicked((Button) { this.removeSelectedRequestHeader(); });

        requestHeadersNameRendererText.addOnEdited(&applyUserEnteredText!("requestHeadersListStore", 0));
        requestHeadersValueRendererText.addOnEdited(&applyUserEnteredText!("requestHeadersListStore", 1));
    }

    /**
     * Connect handlers related to the request data or body.
     */
    void connectRequestDataHandlers()
    {
        auto dataSourceViewSelectLanguageButton = this.getWidget!Button("dataSourceViewSelectLanguageButton");

        dataSourceViewSelectLanguageButton.addOnClicked((Button) {
            this.selectRequestDataLanguagePopover.showAll();
        });
    }

    /**
     * Connect handlers related to the response data or output.
     */
    void connectResponseOutputHandlers()
    {
        auto outputSourceViewSelectLanguageButton = this.getWidget!Button("outputSourceViewSelectLanguageButton");

        outputSourceViewSelectLanguageButton.addOnClicked((Button) {
            this.selectResponseOutputLanguagePopover.showAll();
        });
    }

    /**
     * Connect handlers related to the main widget.
     */
    void connectMainHandlers()
    {
        this.Widget.addOnDestroy((Widget) {
            State.Instance.save();
        });

        this.Widget.addOnShow((Widget) {
            //int w, h;
            //this.getDefaultSize(w, h);
            //this.widthCorrection  = w - editViewWidget.getAllocatedWidth();
            //this.heightCorrection = h - editViewWidget.getAllocatedHeight();

            // By the time this function is executed (which is after the showAll just beneath here),
            // every other class will have registered their loading handlers.
            State.Instance.load();
        });
    }

protected:
    /**
     * Resets the state of the request view as well as the loading screen (i.e. for when a new request is about to be
     * transmitted).
     */
    void resetRequestState()
    {
        auto outputSourceView = this.getWidget!SourceView("outputSourceView");
        auto responseHeadersListStore = this.getObject!ListStore("responseHeadersListStore");
        auto requestLoadingProgressBar = this.getWidget!ProgressBar("requestLoadingProgressBar");

        responseHeadersListStore.clear();
        outputSourceView.getBuffer().setText("");
        requestLoadingProgressBar.setFraction(0.0);

        this.request = null;
    }

    /**
     * Saves the settings of the currently active request to the one currently active (selected from the tree).
     */
    void saveActiveRequest()
    {
        auto iter = this.requestsTree.Widget.getSelectedIter();

        assert(iter);

        int index = this.requestsTree.Store.getValueInt(iter, 1);

        assert(index < this.savedRequests.length);

        this.savedRequests[index] = this.createRequestFromCurrentState();

        this.requestsTree.updateNode(iter, null, to!string(this.savedRequests[index].HttpMethod));
    }

    /**
     * Saves the settings of the currently active request to be accessible as a new node in the request tree under the
     * specified name.
     *
     * @param name The name to give the new request.
     */
    void saveCurrentRequestAsNew(string name)
    {
        this.savedRequests ~= this.createRequestFromCurrentState();

        string methodName = this.getWidget!ComboBoxText("methodComboBox").getActiveText();

        auto iter = this.requestsTree.addNode(name, methodName, cast(int) (this.savedRequests.length - 1));

        this.requestsTree.Widget.getSelection().selectIter(iter);
    }

    /**
     * Adds a new request header row to the request header view with the specified values.
     *
     * @param name  The name of the header.
     * @param value The value fo the haeder.
     *
     * @return An iterator to the newly added row.
     */
    TreeIter addRequestHeaderRow(string name = null, string value = null)
    {
        auto requestHeadersListStore = this.getObject!ListStore("requestHeadersListStore");

        auto iter = new TreeIter();

        requestHeadersListStore.insert(iter, -1);

        if (name)
            requestHeadersListStore.setValue(iter, 0, name);

        if (value)
            requestHeadersListStore.setValue(iter, 1, value);

        return iter;
    }

    /**
     * Removes the selected request header entry to the request header view.
     */
    void removeSelectedRequestHeader()
    {
        auto requestHeadersTreeView = this.getWidget!TreeView("requestHeadersTreeView");
        auto requestHeadersListStore = this.getObject!ListStore("requestHeadersListStore");

        if (auto iter = requestHeadersTreeView.getSelectedIter())
            requestHeadersListStore.remove(iter);
    }

    /**
     * Adds the header for basic (base64 encoded) authentication to the request headers.
     *
     * @param username The username to use during the base64 encoding.
     * @param password The password to use during the base64 encoding.
     */
    void addBasicAuthenticationHeader(string username, string password)
    {
        import std.base64;
        string value = Base64.encode(std.string.representation(username ~ ':' ~ password));

        this.addRequestHeaderRow("Authorization", "Basic " ~ value);
    }

    /**
     * Fetches a list of (additional) request headers that the user wants set for the request.
     *
     * @return An associative array mapping header names to their values.
     */
    string[string] fetchRequestHeaders()
    {
        auto requestHeadersListStore = this.getObject!ListStore("requestHeadersListStore");

        auto iter = new TreeIter();
        iter.setModel(requestHeadersListStore);

        string[string] headers;

        if (requestHeadersListStore.getIterFirst(iter))
        {
            do
            {
                string header = requestHeadersListStore.getValueString(iter, 0);
                string value  = requestHeadersListStore.getValueString(iter, 1);

                headers[header] = value;
            } while (requestHeadersListStore.iterNext(iter));
        }

        return headers;
    }

    /**
     * Sets the request headers in the interface to the specified list.
     *
     * @param headers The headers to load.
     */
    void loadRequestHeaders(string[string] headers)
    {
        auto requestHeadersListStore = this.getObject!ListStore("requestHeadersListStore");

        requestHeadersListStore.clear();

        foreach (header, value; headers)
            this.addRequestHeaderRow(header, value);
    }

    /**
     * Creates a new request object with the callback handlers preinstalled but no data attached.
     *
     * @return The newly created request.
     */
    Request createRequest()
    {
        auto request = new Request();

        this.configureRequest(request);

        return request;
    }

    /**
     * Configures a request object with the callback handlers preinstalled but no data attached.
     *
     * @param request The request to configure.
     */
    void configureRequest(Request request)
    {
        with (request)
        {
            ProgressCallback      = &this.onProgress;
            FinishedCallback      = &this.onFinished;
            ReceiveDataCallback   = &this.onReceiveData;
            ReceiveHeaderCallback = &this.onReceiveHeader;
        }
    }

    /**
     * Creates and sets up a new request object from the values currently set in the interface.
     *
     * @return The newly created request.
     */
    Request createRequestFromCurrentState()
    {
        string methodName = this.getWidget!ComboBoxText("methodComboBox").getActiveText();

        auto request = this.createRequest();

        with (request)
        {
            Url        = this.getWidget!Entry("urlEntry").getText();
            Headers    = this.fetchRequestHeaders();
            HttpMethod = Request.getMethodByName(methodName);

            Data = std.string.representation(this.getWidget!SourceView("dataSourceView").getBuffer().getText());
        }

        return request;
    }

    /**
     * Loads the values of the specified request into the interface.
     *
     * @param request The request to load.
     */
    void loadStateFromRequest(Request request)
    {
        string url = request.Url;
        string data = assumeUTF8Compat(request.Data);

        this.getWidget!ComboBoxText("methodComboBox").setActiveText(to!string(request.HttpMethod));
        this.getWidget!Entry("urlEntry").setText(url ? url : "");
        this.getWidget!SourceView("dataSourceView").getBuffer().setText(data ? data : "");

        this.loadRequestHeaders(request.Headers);
    }

    /**
     * Sends a request using the current parameters set in the fields in the interface.
     */
    void sendRequest()
    {
        string url = this.getWidget!Entry("urlEntry").getText();

        if (url.length == 0)
        {
            this.getWidget!Label("infoBarMessage").setText("Please specify an URL to send the request to.");
            this.getWidget!InfoBar("infoBar").show();

            return;
        }

        this.resetRequestState();

        this.getWidget!Stack("responseStack").setVisibleChild(this.getWidget("requestLoadingBox"));

        this.request = this.createRequestFromCurrentState();

        // log("Performing request to ", url, " with method ", this.request.HttpMethod);

        this.request.sendAsync();

        this.getWidget!Button("sendButton").hide();
        this.getWidget!Button("cancelButton").show();
    }

    /**
     * Cancels the currently active request, if any.
     */
    void cancelRequest()
    {
        // log("Request cancelled");

        if (this.request)
            this.request.cancel();

        this.getWidget!Button("cancelButton").hide();
        this.getWidget!Button("sendButton").show();

        this.getWidget!Stack("responseStack").setVisibleChild(this.getWidget("requestNoteBox"));
    }

protected:
    /**
     * Called when a request is deleted from the requests tree view.
     *
     * @param tree The tree in which the delete occurred.
     * @param iter The iterator to the to be deleted node.
     *
     * @return Whether or not the event should propagate.
     */
    bool onRequestDeleted(RequestsTree tree, TreeIter iter)
    {
        int index = tree.Store.getValueInt(iter, 2);

        assert(index < this.savedRequests.length);

        // NOTE: We don't actually remove the request or we would need to update the indices in the rest of the
        // store.
        //this.savedRequests[index] = null;

        tree.Store.remove(iter);

        if (tree.Store.getIterFirst(iter) == false)
            this.getWidget!Button("saveRequestButton").setSensitive(false);

        return EventPropagation.PROPAGATE;
    };

    /**
     * Called when a previously saved request in the tree view is activated.
     *
     * @param tree The tree in which the delete occurred.
     * @param iter The iterator to the to be deleted node.
     *
     * @return Whether or not the event should propagate.
     */
    bool onRequestActivated(RequestsTree tree, TreeIter iter)
    {
        int index = this.requestsTree.Store.getValueInt(iter, 1);

        assert(index < this.savedRequests.length);

        this.loadStateFromRequest(this.savedRequests[index]);

        this.getWidget!Button("saveRequestButton").setSensitive(true);

        return EventPropagation.PROPAGATE;
    }

protected:
    /**
     * Called when a new header is received.
     *
     * @param name  The name of the header.
     * @param value The value of the header.
     */
    void onReceiveHeader(string name, string value)
    {
        // log("Received header ", name, " = ", value);

        auto responseHeadersTreeView = this.getWidget!TreeView("responseHeadersTreeView");
        auto responseHeadersListStore = this.getObject!ListStore("responseHeadersListStore");

        auto iter = new TreeIter();

        responseHeadersListStore.insert(iter, -1);

        responseHeadersListStore.setValue(iter, 0, name);
        responseHeadersListStore.setValue(iter, 1, value);
    }

    /**
     * Called when a data is received.
     *
     * @param data The data that was received.
     */
    void onReceiveData(immutable(ubyte)[] data)
    {
        // log("Received output ", textualData);

        this.responseDataBuffer ~= data;
    }

    /**
     * Called when progress in the transfer is made.
     *
     * @param percentage The percentage of the transfer that has already been completed.
     */
    void onProgress(uint percentage)
    {
        // log("Received progress ", percentage, " %");

        auto requestLoadingProgressBar = this.getWidget!ProgressBar("requestLoadingProgressBar");

        requestLoadingProgressBar.setFraction(percentage / 100.0);
    }

    /**
     * Called when the request is finished.
     */
    void onFinished()
    {
        // log("Request finished");

        this.getWidget!SourceView("outputSourceView").getBuffer().setText(assumeUTF8Compat(this.responseDataBuffer));

        this.request = null;
        this.responseDataBuffer = null;

        this.getWidget!Button("cancelButton").hide();
        this.getWidget!Button("sendButton").show();

        this.getWidget!Stack("responseStack").setVisibleChild(this.getWidget("responsePaned"));
    }

protected:
    /**
     * The list of known saved requests.
     */
    Request[] savedRequests;

    /**
     * The tree that contains the saved requests.
     */
    RequestsTree requestsTree;

    /**
     * The popover that allows selecting the language for syntax highlighting of the request data.
     */
    Popover selectRequestDataLanguagePopover;

    /**
     * The popover that allows selecting the language for syntax highlighting of the response output.
     */
    Popover selectResponseOutputLanguagePopover;

    /**
     * The popover that is displayed when the user wants to add a new request to enter its name in.
     */
    Popover addNewRequestPopover;

    /**
     * The popover that is displayed when the user wishes to add a new request header.
     */
    Popover addRequestHeaderPopover;

    /**
     * The popover that is displayed when the user wishes to add a new automatically generated authentication header.
     */
    Popover authenticationHeaderPopover;

    /**
     * Buffer for response output.
     *
     * @note Unfortunately, using appendText from GsvSourceView is prone to all kinds of bugs and crashes (i.e.
     * involving gtk_text_iter_forward_line and iterators becoming invalidated).
     */
    immutable(ubyte)[] responseDataBuffer;

    /**
     * The request currently being sent.
     */
    Request request = null;
}
