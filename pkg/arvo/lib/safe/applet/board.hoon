/-  *safe-applet
::
::  The default message board
::
::  The board applet owns the individual threads, along with the next postid.
::
|%
++  parent-event
  $:  now=@da
      =community-signature
  ==
::  the board passes the newly allocated id to the thread
::
+$  child-event
  [id=@ud now=@da =community-signature]
::  the user-event of the board is a new post request
::
+$  user-event
  $%  [%create name=@t type=@t =signature-type]
      [%new-post =post]
::        [%delete-post =post]
  ==
::
+$  private-event
  ~
::
+$  private-state
  $:  next-postid=_1
      other=@
  ==
::
+$  snapshot
  ~
::
+$  child-returned
  $%  [%accepted id=@u]
      [%ignored id=@u]
      [%reject ~]
  ==
::
+$  return-event
  $%  [%accept ~]
      [%reject ~]
  ==
::
+$  on-process-response
  $%  [%create id=@t type=@t =signature-type =child-event]
      [%return =return-event]
  ==
::
+$  post
  $:  subject=@t
      text=@t
  ==
::  +on-route: called when we must route a message to our children
::
::    In the +on-route phase, we take the input parent-event and calculate
::    what the child-event we give to the next path segment is, with the
::    ability to halt the processing of this event by returning ~.
::
++  on-route
  |=  [=path =parent-event =snapshot =private-state]
  ^-  (either return-event child-event)
  ::  we could block the route if we wanted here!
  ::
  [%r next-postid.private-state now.parent-event community-signature.parent-event]
::  +on-process-event: called when we give the passed in user-event to its
::  target node.
::
::    In the +on-process-event phase, we take the parent-event and the
::    user-event that the user passed to, and create a list of effects along
::    with modifications to private state that the user never sees.
::
++  on-process-event
  |=  [=parent-event =user-event =snapshot =private-state]
  ^-  [on-process-response _private-state]
  ::
  ?-    -.user-event
      %new-post
    =/  id  next-postid.private-state
    ::  new threads inherit the board configuration
    ::
    :_  private-state
    :*  %create
        (scot %ud id)
        %thread
        %inherit
        [next-postid.private-state now.parent-event community-signature.parent-event]
    ==
  ::
      %create
    [[%return [%accept ~]] private-state]
  ==
::  +apply-event-to-snapshot: called to replay the event log
::
::    In the +apply-event-to-snapshot phase, we take a %log event generated
::    from +on-process-event and modify the snapshot. Behind the scenes, the
::    event log is synced to clients, who call this to update their own
::    snapshots of the current state.
::
++  apply-event-to-snapshot
  |=  [=user-event =private-event =snapshot]
  ^-  _snapshot
  ~&  %todo
  snapshot
::  +on-child-return: called on parent nodes when +on-process-event creates a %return-event
::
::    In the +on-return-event phase, we take a %return event generated by a
::    child node and modify the state with it. This is how
::
::    TODO: When we have an accepted message, we should maintain an internal
::    bumplist on the way to archiving.
::
++  on-child-return
  |=  [=child-returned =private-state]
  ^-  [return-event _private-state]
  ?-    -.child-returned
      %accepted
    ?>  =(id.child-returned next-postid.private-state)
    [[%accept ~] private-state(next-postid +(next-postid.private-state))]
  ::
      %ignored
    ::  accept quietly, without consuming the postid.
    ::
    [[%accept ~] private-state]
  ::
      %reject
    [[%reject ~] private-state]
  ==
--

