::  link-proxy-hook: make local pages available to foreign ships
::
::    this is a "proxy" style hook, relaying foreign subscriptions into local
::    stores if permission conditions are met.
::    the patterns herein should one day be generalized into a proxy-hook lib.
::
::    this adopts a very primitive view of groups-store as containing only
::    groups of interesting (rather than uninteresting) ships. it sets the
::    permission condition to be that ship must be in group matching the path
::    it's subscribing to.
::    we check this on-watch, but also subscribe to groups so that we can kick
::    subscriptions if needed (eg ship removed from group).
::
::    we deduplicate incoming subscriptions on the same path, ensuring we have
::    exactly one local subscription per unique incoming subscription path.
::    this comes at the cost of assuming that the store's initial response is
::    whatever's returned by the scry at that path, but perhaps that should
::    become part of the stores standard anyway.
::
::    when adding support for new paths, the only things you'll likely want
::    to touch are +permitted, +initial-response, & maybe +handle-group-update.
::
/-  group-store
/+  *link, default-agent, verb, dbug
|%
+$  state-0
  $:  %0
      ::TODO  we use this to detect "first sub started" and "last sub left",
      ::      but can't we use [wex sup]:bowl for that?
      active=(map path (set ship))
  ==
::
+$  card  card:agent:gall
--
::
=|  state-0
=*  state  -
::
%-  agent:dbug
%+  verb  |
^-  agent:gall
=<
  |_  =bowl:gall
  +*  this  .
      do    ~(. +> bowl)
      def   ~(. (default-agent this %&) bowl)
  ::
  ++  on-init
    ^-  (quip card _this)
    :_  this
    [watch-groups:do]~
  ::
  ++  on-save  !>(state)
  ++  on-load
    |=  old=vase
    ^-  (quip card _this)
    [~ this(state !<(state-0 old))]
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card _this)
    ::  the local ship should just use link-store directly
    ::TODO  do we want to allow this anyway, to avoid client-side target checks?
    ::
    ?<  (team:title [our src]:bowl)
    ?>  (permitted:do src.bowl path)
    =^  cards  state
      (start-proxy:do src.bowl path)
    [cards this]
  ::
  ++  on-leave
    |=  =path
    ^-  (quip card _this)
    =^  cards  state
      (stop-proxy:do src.bowl path)
    [cards this]
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    ?:  ?=([%groups ~] wire)
      =^  cards  state
        (take-groups-sign:do sign)
      [cards this]
    ?:  ?=([%proxy ^] wire)
      =^  cards  state
        (handle-proxy-sign t.wire sign)
      [cards this]
    ~|  [dap.bowl %weird-wire wire]
    !!
  ::
  ++  on-poke  on-poke:def
  ++  on-peek  on-peek:def
  ++  on-arvo  on-arvo:def
  ++  on-fail  on-fail:def
  --
::
|_  =bowl:gall
++  permitted
  |=  [who=ship =path]
  ^-  ?
  ::  we only expose group-specific /local-pages and /annotations,
  ::  and only to ships in the relevant group.
  ::  (no url-specific annotations subscriptions, either.)
  ::
  =/  target=(unit ^path)
    ?:  ?=([%local-pages ^] path)
      `t.path
    ?:  ?=([%annotations ~ ^] path)
      `t.t.path
    ~
  ?~  target  |
  =;  group
    ?&  ?=(^ group)
        (~(has in u.group) who)
    ==
  %+  scry-for  (unit group:group-store)
  [%group-store u.target]
::
::  groups subscription
::TODO  largely copied from link-listen-hook. maybe make a store-listener lib?
::
++  watch-groups
  ^-  card
  [%pass /groups %agent [our.bowl %group-store] %watch /all]
::
++  take-groups-sign
  |=  =sign:agent:gall
  ^-  (quip card _state)
  ?-  -.sign
    %poke-ack   ~|([dap.bowl %unexpected-poke-ack /groups] !!)
    %kick       [[watch-groups]~ state]
  ::
      %watch-ack
    ?~  p.sign  [~ state]
    =/  =tank
      :-  %leaf
      "{(trip dap.bowl)} failed subscribe to group store. very wrong!"
    %-  (slog tank u.p.sign)
    [~ state]
  ::
      %fact
    =*  mark  p.cage.sign
    =*  vase  q.cage.sign
    ?+  mark  ~|([dap.bowl %unexpected-mark mark] !!)
      %group-initial  [~ state]
      %group-update   (handle-group-update !<(group-update:group-store vase))
    ==
  ==
::
++  handle-group-update
  |=  upd=group-update:group-store
  ^-  (quip card _state)
  :_  state
  ?.  ?=(%remove -.upd)  ~
  =/  whos=(list ship)  ~(tap in members.upd)
  |-  ^-  (list card)
  ?~  whos  ~
  ::  no need to remove to ourselves
  ::
  ?:  =(our.bowl i.whos)
    $(whos t.whos)
  :_  $(whos t.whos)
  ::NOTE  this depends kind of unfortunately on the fact that we only accept
  ::      subscriptions to /local-pages//* paths. it'd be more correct if we
  ::      "just" looked at all paths in the map, and found the matching ones.
  ::TODO  what exactly did i mean by this?
  %+  kick-proxies  i.whos
  :~  [%local-pages pax.upd]
      [%annotations '' pax.upd]
  ==
::
::  proxy subscriptions
::
++  kick-proxies
  |=  [who=ship paths=(list path)]
  ^-  card
  [%give %kick paths `who]
::
++  handle-proxy-sign
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _state)
  ?-  -.sign
    %poke-ack     ~|([dap.bowl %unexpected-poke-ack wire] !!)
    %fact         [[%give %fact ~[wire] cage.sign]~ state]
    %kick         [[(proxy-pass-link-store wire %watch wire)]~ state]
  ::
      %watch-ack
    ?~  p.sign  [~ state]
    =/  =tank
      :-  %leaf
      "{(trip dap.bowl)} failed subscribe to link-store. very wrong!"
    %-  (slog tank u.p.sign)
    [~ state]
  ==
::
++  proxy-pass-link-store
  |=  [=path =task:agent:gall]
  ^-  card
  :*  %pass
      [%proxy path]
      %agent
      [our.bowl %link-store]
      task
  ==
::
++  initial-response
  |=  =path
  ^-  card
  =;  =initial
    [%give %fact ~ %link-initial !>(initial)]
  ?+  path  !!
      [%local-pages ^]
    :-  %local-pages
    %+  scry-for  (map ^path pages)
    [%link-store path]
  ::
      [%annotations %$ ^]
    :-  %annotations
    %+  scry-for  (per-path-url notes)
    [%link-store path]
  ==
::
++  start-proxy
  |=  [who=ship =path]
  ^-  (quip card _state)
  :_  state(active (~(put ju active) path who))
  :_  ~
  ::  if we already have a local subscription open,
  ::
  ?.  =(~ (~(get ju active) path))
    ::  gather the initial response ourselves, and send that.
    ::
    (initial-response path)
  ::  else, open a local subscription,
  ::  sending outward its initial response when we hear it.
  ::
  (proxy-pass-link-store path %watch path)
::
++  stop-proxy
  |=  [who=ship =path]
  ^-  (quip card _state)
  =.  active  (~(del ju active) path who)
  :_  state
  ::  if there are still subscriptions remaining, do nothing.
  ::
  ?.  =(~ (~(get ju active) path))  ~
  ::  else, close the local subscription.
  ::
  [(proxy-pass-link-store path %leave ~)]~
::
++  scry-for
  |*  [=mold app=term =path]
  .^  mold
    %gx
    (scot %p our.bowl)
    app
    (scot %da now.bowl)
    (snoc `^path`path %noun)
  ==
--
