/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.StateAwareInterface;

import glib.KeyFile;

/**
 * Describes functionality that must be exposed by classes that wish to read and/or write data from/to the state file.
 */
interface StateAwareInterface
{
public:
    /**
     * Loads state from the specified file.
     *
     * @param file      The KeyFile (basically a .ini file) that contains the state to load.
     * @param groupName The group name that should be used for reading actions, see also {@see saveState} regarding
     *                  custom (nested) groups.
     */
    void loadState(KeyFile file, string groupName);

    /**
     * Saves state to the specified file.
     *
     * @param file      The KeyFile (basically a .ini file) that you can use to save state to.
     * @param groupName The group name that should be used for writing actions, if you wish to create your own groups,
     *                  make sure to prepend this to your group name, separated by an underscore.
     */
    void saveState(KeyFile file, string groupName);
}
