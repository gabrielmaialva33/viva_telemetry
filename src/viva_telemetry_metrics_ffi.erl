%% FFI module for viva_telemetry/metrics
%% Uses ETS for process-safe metric storage

-module(viva_telemetry_metrics_ffi).
-export([
    get_counter_value/1,
    add_counter_value/2,
    get_gauge_value/1,
    set_gauge_value/2,
    get_all_counters/0,
    get_all_gauges/0,
    get_beam_memory/0,
    clear_all/0,
    ensure_table/0
]).

-define(COUNTER_TABLE, viva_telemetry_counters).
-define(GAUGE_TABLE, viva_telemetry_gauges).

%% Ensure ETS tables exist
ensure_table() ->
    case ets:info(?COUNTER_TABLE) of
        undefined ->
            ets:new(?COUNTER_TABLE, [named_table, public, set, {write_concurrency, true}]);
        _ -> ok
    end,
    case ets:info(?GAUGE_TABLE) of
        undefined ->
            ets:new(?GAUGE_TABLE, [named_table, public, set, {write_concurrency, true}]);
        _ -> ok
    end,
    ok.

%% Counter operations
get_counter_value(Key) ->
    ensure_table(),
    case ets:lookup(?COUNTER_TABLE, Key) of
        [{Key, Value}] -> Value;
        [] -> 0
    end.

add_counter_value(Key, Value) ->
    ensure_table(),
    _ = ets:update_counter(?COUNTER_TABLE, Key, {2, Value}, {Key, 0}),
    nil.

%% Gauge operations
get_gauge_value(Key) ->
    ensure_table(),
    case ets:lookup(?GAUGE_TABLE, Key) of
        [{Key, Value}] -> Value;
        [] -> 0.0
    end.

set_gauge_value(Key, Value) ->
    ensure_table(),
    ets:insert(?GAUGE_TABLE, {Key, Value}),
    nil.

%% Get all counters as dict
get_all_counters() ->
    ensure_table(),
    List = ets:tab2list(?COUNTER_TABLE),
    maps:from_list(List).

%% Get all gauges as dict
get_all_gauges() ->
    ensure_table(),
    List = ets:tab2list(?GAUGE_TABLE),
    maps:from_list(List).

%% Get BEAM memory info
get_beam_memory() ->
    MemInfo = erlang:memory(),
    #{
        <<"total">> => proplists:get_value(total, MemInfo, 0),
        <<"processes">> => proplists:get_value(processes, MemInfo, 0),
        <<"processes_used">> => proplists:get_value(processes_used, MemInfo, 0),
        <<"system">> => proplists:get_value(system, MemInfo, 0),
        <<"atom">> => proplists:get_value(atom, MemInfo, 0),
        <<"atom_used">> => proplists:get_value(atom_used, MemInfo, 0),
        <<"binary">> => proplists:get_value(binary, MemInfo, 0),
        <<"code">> => proplists:get_value(code, MemInfo, 0),
        <<"ets">> => proplists:get_value(ets, MemInfo, 0)
    }.

clear_all() ->
    ensure_table(),
    ets:delete_all_objects(?COUNTER_TABLE),
    ets:delete_all_objects(?GAUGE_TABLE),
    nil.
