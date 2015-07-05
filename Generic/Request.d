/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Generic.Request;

import std.string;
import std.net.curl;
import std.conv : to;
import std.parallelism;
import std.typecons : Nullable;

import Generic.Utility;

/**
 * A request based on curl.
 *
 * @todo Split this to use a strategy (CurlRequestStrategy) or into subclasses.
 */
class Request
{
public:
    /**
     * A list of supported methods.
     */
    enum Method
    {
        GET,
        PUT,
        POST,
        DELETE,
        HEAD,
        OPTIONS
    }

public:
    @property
    {
        auto Data()
        {
            return this.data;
        }

        void Data(immutable(ubyte)[] data)
        {
            this.data = data;
        }

        /**
         * Retrieves the content type used. Use the 'Content-Type' key in the Headers property to govern this setting.
         * Defaults to "application/x-www-form-urlencoded".
         */
        auto ContentType()
        {
            auto headers = this.Headers;

            if ("content-type" in headers)
                return headers["content-type"];

            return "application/x-www-form-urlencoded";
        }

        auto ProgressCallback()
        {
            return this.progressCallback;
        }

        void ProgressCallback(void delegate(uint percentage) callback)
        {
            this.progressCallback = callback;
        }

        auto FinishedCallback()
        {
            return () {
                threadsAddIdleDelegate(this.finishedCallback);
            };
        }

        void FinishedCallback(void delegate() callback)
        {
            this.finishedCallback = callback;
        }

        auto ReceiveDataCallback()
        {
            return this.receiveDataCallback;
        }

        void ReceiveDataCallback(void delegate(immutable(ubyte)[] data) callback)
        {
            this.receiveDataCallback = callback;
        }

        auto ReceiveHeaderCallback()
        {
            return this.receiveHeaderCallback;
        }

        void ReceiveHeaderCallback(void delegate(string name, string value) callback)
        {
            this.receiveHeaderCallback = callback;
        }

        auto Headers()
        {
            return this.headers;
        }

        auto Headers(string[string] headers)
        {
            this.headers = typeof(this.headers).init;

            foreach (header, value; headers)
                this.headers[header.toLower()] = value;
        }

        auto Url()
        {
            return this.url;
        }

        void Url(string url)
        {
            this.url = url;
        }

        auto HttpMethod()
        {
            return this.httpMethod;
        }

        void HttpMethod(Method method)
        {
            this.httpMethod = method;
        }
    }

public:
    /**
     * Sends a request in an asynchronous way by putting it in the D taskpool (i.e. this method will immediately return
     * and is non-blocking).
     */
    void sendAsync(string url = null, Nullable!Method method = Nullable!Method())
    {
        synchronized this.terminated = false;
        taskPool.put(task(&this.send, url, method));
    }

    /**
     * Cancels the current request. Note that this is only useful if the request is asynchronous (if it isn't and it is
     * sent after this method is invoked, event handlers will not be invoked properly).
     *
     * An important thing to note is that D does not offer any functionality for actually killing tasks (or threads, for
     * that matter), so we have to do the next best thing: which is absolutely nothing; the request will just continue
     * in the background, but no event handlers will be invoked so the caller will not be bothered by it.
     */
    void cancel()
    {
        synchronized this.terminated = true;
    }

    /**
     * Sends a request (synchronously, i.e. in a blocking way) using the specified settings.
     */
    void send(string url = null, Nullable!Method method = Nullable!Method())
    {
        auto request = HTTP();

        auto requestMethod = method.isNull() ? this.HttpMethod : method.get();

        request.url = url ? url : this.Url;
        request.method = this.getMappedMethod(requestMethod);

        foreach (header, value; this.Headers)
            request.addRequestHeader(header, value);

        if (this.Data.length > 0)
        {
            size_t bytesSent = 0;

            request.contentLength = this.Data.length;
            request.onSend = (void[] data) {
                synchronized if (!this.terminated)
                {
                    auto length = data.length;
                    auto remainingBytes = (this.Data.length - bytesSent);

                    if (length > remainingBytes)
                        length = remainingBytes;

                    if (length == 0)
                        return 0;

                    data[0 .. length] = this.Data[bytesSent .. (bytesSent + length)].dup;

                    bytesSent += length;

                    return length;
                }

                return -1;
            };
        }

        request.onReceiveHeader = (in char[] key, in char[] value) {
            synchronized if (!this.terminated)
                this.ReceiveHeaderCallback()(to!string(key), to!string(value));
        };

        request.onReceive = (ubyte[] data) {
            synchronized if (!this.terminated)
                this.ReceiveDataCallback()(to!(immutable(ubyte)[])(data));

            return data.length; // We've read all the data.
        };

        request.onProgress = (size_t downloadSize, size_t downloadedBytes, size_t uploadSize, size_t uploadedBytes) {
            if (downloadSize > 0 && downloadedBytes <= downloadSize)
            {
                synchronized if (!this.terminated)
                    this.ProgressCallback()(cast(uint) (downloadedBytes / downloadSize));
            }

            return 0; // Success, do not abort the transfer.
        };

        request.perform();

        synchronized if (!this.terminated)
            this.FinishedCallback()();
    }

public:
    /**
     * Returns the correct enum value that matches the specified string name.
     */
    static Method getMethodByName(string name)
    {
        Request.Method requestMethod;

        foreach (method; __traits(allMembers, Request.Method))
            if (method == name)
                return mixin("Request.Method." ~ method);

        throw new Exception("Unknown request method name!");
    }

protected:
    /**
     * Retrieves the cURL method equivalent of the specified method.
     */
    HTTP.Method getMappedMethod(Method method)
    {
        auto map = [
            Method.GET      : HTTP.Method.get,
            Method.PUT      : HTTP.Method.put,
            Method.POST     : HTTP.Method.post,
            Method.DELETE   : HTTP.Method.del,
            Method.HEAD     : HTTP.Method.head,
            Method.OPTIONS  : HTTP.Method.options
        ];

        if (method !in map)
            throw new Exception("Invalid request method passed for request!");

        return map[method];
    }

protected:
    /**
     * Whether or not the request has been terminated.
     */
    bool terminated = false;

    /**
     * The url to send the request to.
     */
    string url;

    /**
     * The HTTP method used by the request.
     */
    Method httpMethod;

    /**
     * The data to send with the request.
     */
    immutable(ubyte)[] data;

    /**
     * Additional headers to set for the request. Headers that are also present by default will be overwritten. Note
     * that headers are case insensitive and all converted to lower case before sending them!
     */
    string[string] headers;

    /**
     * The callback to invoke whenever data is received (can de called multiple times!).
     */
    void delegate(immutable(ubyte)[]) receiveDataCallback;

    /**
     * The callback to invoke whenever (response) headers are received.
     */
    void delegate(string, string) receiveHeaderCallback;

    /**
     * The callback to invoke whenever the transfer progresses.
     */
    void delegate(uint percentage) progressCallback;

    /**
     * The callback to invoke whenever the request has finished executing.
     */
    void delegate() finishedCallback;
}
