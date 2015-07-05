/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.State;

import std.file;

import glib.Util;
import glib.KeyFile;

import Generic.Mixins.Singleton;
import Generic.StateAwareInterface;

/**
 * Manages loading and saving application state (such as previously opened files).
 */
class State
{
    mixin Singleton;

public:
    auto ConfigDirectory()
    {
        return this.configDirectory;
    }

    void ConfigDirectory(string directory)
    {
        this.configDirectory = directory;
    }

    auto ConfigFile()
    {
        return this.configFile;
    }

    void ConfigFile(string file)
    {
        this.configFile = file;
    }

public:
    /**
     * Registers the specified object for changes so that it is notified when changes to the state file occur.
     */
    void register(StateAwareInterface object)
    {
        this.listeners ~= object;
    }

    /**
     * Reads previously saved state from the existing file.
     */
    void load()
    {
        KeyFile keyFile = new KeyFile();

        if (!exists(this.ConfigDirectory))
            mkdirRecurse(this.ConfigDirectory);

        if (exists(this.ConfigFile) && !keyFile.loadFromFile(ConfigFile, GKeyFileFlags.KEEP_COMMENTS))
            throw new Exception("Couldn't load state from " ~ this.ConfigFile ~ "! It may be corrupt or unreadable!");

        foreach (listener; this.listeners)
            listener.loadState(keyFile, null);
    }

    /**
     * Writes application state to the config directory.
     */
    void save()
    {
        KeyFile keyFile = new KeyFile();

        foreach (listener; this.listeners)
            listener.saveState(keyFile, null);

        // Write the actual file. Note that the directory is already created in the loader.
        try
        {
            size_t ignore;
            std.file.write(this.ConfigFile, keyFile.toData(ignore));
        }

        catch(FileException e)
        {
            throw new Exception("Couldn't save state to " ~ this.ConfigFile ~ "! It may be unwritable!");
        }
    }

private:
    /**
     * Constructor.
     */
    this()
    {

    }

private:
    /**
     * A list of objects that listen to state saving and loading.
     */
    StateAwareInterface[] listeners;

    /**
     * The directory to write and read the state file to.
     */
    string configDirectory;

    /**
     * The file to write and read state from.
     */
    string configFile;
}
