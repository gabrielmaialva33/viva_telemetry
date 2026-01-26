%% FFI module for viva_telemetry
%% Provides process dictionary access and time functions

-module(viva_telemetry_ffi).
-export([
    now_microseconds/0,
    get_handlers/0,
    set_handlers/1,
    get_context/0,
    set_context/1,
    should_sample/1
]).

%% Get current time in microseconds
now_microseconds() ->
    erlang:system_time(microsecond).

%% Handler storage in process dictionary
-define(HANDLERS_KEY, viva_telemetry_handlers).
-define(CONTEXT_KEY, viva_telemetry_context).

get_handlers() ->
    case erlang:get(?HANDLERS_KEY) of
        undefined -> [];
        Handlers -> Handlers
    end.

set_handlers(Handlers) ->
    erlang:put(?HANDLERS_KEY, Handlers),
    nil.

%% Context storage in process dictionary
get_context() ->
    case erlang:get(?CONTEXT_KEY) of
        undefined -> gleam@dict:new();
        Context -> Context
    end.

set_context(Context) ->
    erlang:put(?CONTEXT_KEY, Context),
    nil.

%% Sampling - returns true with probability Rate (0.0 to 1.0)
should_sample(Rate) when Rate >= 1.0 ->
    true;
should_sample(Rate) when Rate =< 0.0 ->
    false;
should_sample(Rate) ->
    rand:uniform() < Rate.
