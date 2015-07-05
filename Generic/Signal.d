/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Signal;

/**
 * A very simple signal structure, to avoid having to use D's std.signals, abusing GTK's SimpleAction and finally
 * implementing custom GTK signals.
 *
 * @note If you define an instance of this struct as static, you can have a per-class signal rather than a per-object
 *       signal (you could then pass the affected object emitting the signal as first parameter).
 */
struct Signal(string name, parameters...)
{
public:
    alias callbackType = bool delegate(parameters);

public:
    /**
     * Sends out the signal with the specified parameters.
     */
    void send(parameters p)
    {
        debug
        {
            if (this.callbacks.length == 0)
            {
                import std.string : format;
                import std.stdio  : writeln;

                // These warnings are usually spurious, but sometimes you just forgot to attach a handler.
                writeln("WARNING: Signal %s sent but no listeners attached!".format(name));
            }
        }

        foreach (callback; this.callbacks)
            if (callback(p))
                break;
    }

    /**
     * Adds a new listener to the signal, which must be a delegate with the same parameters as the signal.
     */
    void listen(callbackType callback)
    {
        this.callbacks ~= callback;
    }

private:
    /**
     * An array of callbacks invoked when the signal is sent.
     */
    callbackType[] callbacks;
}
