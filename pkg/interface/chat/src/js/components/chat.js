import React, { Component } from 'react';
import classnames from 'classnames';
import _ from 'lodash';

import { Route, Link } from "react-router-dom";
import { store } from "/store";

import { Message } from '/components/lib/message';
import { SidebarSwitcher } from '/components/lib/icons/icon-sidebar-switch.js';
import { ChatTabBar } from '/components/lib/chat-tabbar';
import { ChatInput } from '/components/lib/chat-input';
import { deSig } from '/lib/util';


export class ChatScreen extends Component {
 constructor(props) {
   super(props);

   this.state = {
     numPages: 1,
     scrollLocked: false
   };

   this.hasAskedForMessages = false;
   this.onScroll = this.onScroll.bind(this);
   this.messages = this.messagesWithPending.bind(this);

   this.updateReadInterval = setInterval(
     this.updateReadNumber.bind(this),
     1000
   );
 }

 componentDidMount() {
   this.updateReadNumber();
   this.scrollToBottom("auto");
 }

 componentWillUnmount() {
   if (this.updateReadInterval) {
     clearInterval(this.updateReadInterval);
     this.updateReadInterval = null;
   }
 }

 componentDidUpdate(prevProps, prevState) {
   const { props, state } = this;

   const station =
     props.match.params[1] === undefined ?
     `/${props.match.params.ship}/${props.match.params.station}` :
     `/${props.match.params[1]}/${props.match.params.ship}/${props.match.params.station}`;

   // Switched chats
   if (
     prevProps.match.params.station !== props.match.params.station ||
     prevProps.match.params.ship !== props.match.params.ship
   ) {
     this.hasAskedForMessages = false;

     clearInterval(this.updateReadInterval);

     this.setState(
       {
         station: station,
         scrollLocked: false
       },
       () => {
         this.scrollToBottom("auto");
         this.updateReadInterval = setInterval(
           this.updateReadNumber.bind(this),
           1000
         );
         this.updateReadNumber();
       }
     );
   // Switched to chat
   } else if (props.chatInitialized && !(station in props.inbox)) {
     props.history.push("/~chat");
   // A new message came in, other cases
   } else {
    this.scrollToBottom("auto");
    if (
     props.envelopes.length - prevProps.envelopes.length >=
     200
    ) {
     this.hasAskedForMessages = false;
    }
   }
 }

 updateReadNumber() {
   const { props, state } = this;
   if (props.read < props.length) {
     props.api.chat.read(props.station);
   }
 }

 askForMessages() {
   const { props, state } = this;

   if (
     state.numPages * 100 < props.length - 400 ||
     this.hasAskedForMessages
   ) {
     return;
   }

   if (props.length > 0) {
     let end = props.envelopes[0].number;
     if (end > 0) {
       let start = end - 400 > 0 ? end - 400 : 0;

       if (start === 0 && end === 1) {
         return;
       }

       this.hasAskedForMessages = true;

       props.subscription.fetchMessages(start, end - 1, props.station);
     }
   }
 }

 scrollToBottom(behavior = 'smooth') {
   if (!this.state.scrollLocked && this.scrollElement) {
     this.scrollElement.scrollIntoView({ behavior });
   }
 }

 onScroll(e) {
   if (
     navigator.userAgent.includes("Safari") &&
     navigator.userAgent.includes("Chrome")
   ) {
     // Google Chrome
     if (e.target.scrollTop === 0) {
       this.setState(
         {
           numPages: this.state.numPages + 1,
           scrollLocked: true
         },
         () => {
           this.askForMessages();
         }
       );
     } else if (
       e.target.scrollHeight - Math.round(e.target.scrollTop) ===
       e.target.clientHeight
     ) {
       this.setState({
         numPages: 1,
         scrollLocked: false
       });
     }
   } else if (navigator.userAgent.includes("Safari")) {
     // Safari
     if (e.target.scrollTop === 0) {
       this.setState({
         numPages: 1,
         scrollLocked: false
       });
     } else if (
       e.target.scrollHeight + Math.round(e.target.scrollTop) <=
       e.target.clientHeight + 10
     ) {
       this.setState(
         {
           numPages: this.state.numPages + 1,
           scrollLocked: true
         },
         () => {
           this.askForMessages();
         }
       );
     }
   } else {
     console.log("Your browser is not supported.");
   }
 }

 messagesWithPending() {
   const { props, state } = this;
   let messages = props.envelopes.slice(0);

   if (messages.length > 100 * state.numPages) {
     messages = messages.slice(
       messages.length - 100 * state.numPages,
       messages.length
     );
   }

   let pendingMessages = props.pendingMessages.has(props.station)
     ? props.pendingMessages.get(props.station)
     : [];

   pendingMessages.map(function(value) {
     return (value.pending = true);
   });

   return messages.concat(pendingMessages);
 }

 render() {
   const { props } = this;

   const lastMsgNum = props.envelopes.slice(0) > 0 ? props.envelopes.slice(0) : 0
   const messages = this.messagesWithPending();

   const messagesFragment = messages.map((msg, i) => {
     // Render sigil if previous message is not by the same sender
     let aut = ["author"];
     let renderSigil =
       _.get(messages[i - 1], aut) !==
       _.get(msg, aut, msg.author);
     let paddingTop = renderSigil;
     let paddingBot =
       _.get(messages[i - 1], aut) !==
       _.get(msg, aut, msg.author);

     return (
       <Message
         key={msg.uid}
         msg={msg}
         contacts={props.contacts}
         renderSigil={renderSigil}
         paddingTop={paddingTop}
         paddingBot={paddingBot}
         pending={!!msg.pending}
       />
     );
   });

   const group = Array.from(props.group.values());

   const isinPopout = props.popout ? "popout/" : "";

   let ownerContact = (window.ship in props.contacts)
     ? props.contacts[window.ship] : false;

   let title = props.station.substr(1);

   if (props.association && "metadata" in props.association) {
     title =
       props.association.metadata.title !== ""
         ? props.association.metadata.title
         : props.station.substr(1);
   }

   return (
     <div
       key={props.station}
       className="h-100 w-100 overflow-hidden flex flex-column">
       <div
         className="w-100 dn-m dn-l dn-xl inter pt4 pb6 pl3 f8"
         style={{ height: "1rem" }}>
         <Link to="/~chat/">{"⟵ All Chats"}</Link>
       </div>
       <div
         className={"pl4 pt2 bb b--gray4 b--gray1-d bg-gray0-d flex relative" +
         "overflow-x-scroll overflow-x-auto-l overflow-x-auto-xl flex-shrink-0"}
         style={{ height: 48 }}>
         <SidebarSwitcher
           sidebarShown={this.props.sidebarShown}
           popout={this.props.popout}
         />
         <Link to={`/~chat/` + isinPopout + `room` + props.station}
         className="pt2 white-d">
           <h2
             className={"dib f9 fw4 lh-solid v-top " +
             ((title === props.station.substr(1)) ? "mono" : "")}
             style={{ width: "max-content" }}>
             {title}
           </h2>
         </Link>
         <ChatTabBar
           {...props}
           station={props.station}
           numPeers={group.length}
           isOwner={deSig(props.match.params.ship) === window.ship}
           popout={this.props.popout}
         />
       </div>
       <div
         className="overflow-y-scroll bg-white bg-gray0-d pt3 pb2 flex flex-column"
         style={{ height: "100%", resize: "vertical" }}
         onScroll={this.onScroll}>
         {messagesFragment}
         <div
           ref={el => {
             this.scrollElement = el;
           }}></div>
       </div>
       <ChatInput
         api={props.api}
         numMsgs={lastMsgNum}
         station={props.station}
         owner={deSig(props.match.params.ship)}
         ownerContact={ownerContact}
         permissions={props.permissions}
         placeholder="Message..."
       />
     </div>
   );
 }
}
