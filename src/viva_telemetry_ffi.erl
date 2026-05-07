%% FFI module for viva_telemetry
%% Provides process dictionary access and time functions

-module(viva_telemetry_ffi).
-export([
    now_microseconds/0,
    get_handlers/0,
    set_handlers/1,
    get_context/0,
    set_context/1,
    should_sample/1,
    print_stderr/1,
    erlang_log/4
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

%% Print to stderr
print_stderr(Msg) ->
    io:format(standard_error, "~ts~n", [Msg]),
    nil.

erlang_log(Level, LoggerName, Message, Fields) ->
    Report = maps:from_list([{msg, Message} | fields_to_report(Fields)]),
    Metadata = #{logger_name => LoggerName},
    logger:log(level_atom(Level), Report, Metadata),
    nil.

fields_to_report(Fields) when is_map(Fields) ->
    maps:to_list(Fields);
fields_to_report(_) ->
    [].

level_atom(<<"EMERGENCY">>) -> emergency;
level_atom(<<"ALERT">>) -> alert;
level_atom(<<"CRITICAL">>) -> critical;
level_atom(<<"ERROR">>) -> error;
level_atom(<<"WARNING">>) -> warning;
level_atom(<<"NOTICE">>) -> notice;
level_atom(<<"INFO">>) -> info;
level_atom(<<"DEBUG">>) -> debug;
level_atom(<<"TRACE">>) -> debug;
level_atom("EMERGENCY") -> emergency;
level_atom("ALERT") -> alert;
level_atom("CRITICAL") -> critical;
level_atom("ERROR") -> error;
level_atom("WARNING") -> warning;
level_atom("NOTICE") -> notice;
level_atom("INFO") -> info;
level_atom("DEBUG") -> debug;
level_atom("TRACE") -> debug;
level_atom(_) -> info.
