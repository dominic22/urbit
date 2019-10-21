::  Would love to see a proper stateful terminal handler.  Ideally,
::  you'd be able to ^X into the virtual ship, like the old ^W.
::
::  However, that's probably not the primary way of interacting with
::  it.  In practice, most of the time you'll be running from a file
::  (eg for automated testing) or fanning the same command to multiple
::  ships or otherwise making use of the fact that we can
::  programmatically send events.
::
/-  aquarium
/+  aqua-vane-imp
|%
++  handle-blit
  |=  [who=@p way=wire %blit blits=(list blit:dill)]
  ^-  (list card:agent:mall)
  =/  last-line
    %+  roll  blits
    |=  [b=blit:dill line=tape]
    ?-    -.b
        %lin  (tape p.b)
        %mor  ~&  "{<who>}: {line}"  ""
        %hop  line
        %bel  line
        %clr  ""
        %sag  ~&  [%save-jamfile-to p.b]  line
        %sav  ~&  [%save-file-to p.b]  line
        %url  ~&  [%activate-url p.b]  line
    ==
  ~?  !=(~ last-line)  last-line
  ~
--
::
%-  aqua-vane-imp
|_  =bowl:mall
+*  this  .
++  handle-unix-effect
  |=  [who=@p ue=unix-effect:aquarium]
  ^-  (quip card:agent:mall _this)
  =/  cards
    ?+  -.q.ue  ~
      %blit  (handle-blit who ue)
    ==
  [cards this]
::
++  handle-arvo-response  _!!
--