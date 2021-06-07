import { Channel, Push, Socket } from "phoenix";

// channel: on push join leave

// on, push -> webrtc ma na nie wplyw
// join, leave -> webrtc sie ich nie dotyka

// rzeczy ktore webrtc wrzuca w joinie, maja leciec w zwyklym callbacku

// teraz na join leci:
//   - lista participantow
//   - moje ID
//   - max display number

//  lista participantow jest potrzebna tez poza webrtc, np do pokazywania max 4 userow
//  czy na pewno?

//  info nt. MID powinno byc tylko handlowane przez webrtc

// skoro dostajesz poza webrtc info o swoim ID, to powinieneś np dostawać poza webrtc info o idkach innych participantow

//
// teraz odpalenie "start" powoduje wywolanie handle_other({:new_peer, ...}, ...) w Pipeline
//

// obecnie jest tak:
//  C  S
//  --> relay media, display name
//  <-- max display num, user id, participants list
//  --> "start", jest tworzony wtedy po stronie serwera proces dziecko %WebRTC.Endpoint{}, ktory triggeruje sdp offer i signalling
//  <--> sdp signalling

// ma byc tak
//  C  S
//  |-> _
//  <-= user id, max displany num, participants list
//  --> "webrtc start", relay media, display name
//
//  <--> sdp signalling

// klient robi join, u serwera wstaje jego channel
// server przesyla mu jego ID i configowe rzeczy niezwiązane z WebRTC, takie jak maxDisplayNum
// WebRTC po stronie klienta wstaje, robi "start" wsadzając tam swoje ID, relayMedia, displayName
// server (pipeline) akceptuje nowego peera lub nie, jezeli tak to
//    1) wysyla do peera liste participantow juz obecnych, notyfikuje wszystkicj participantow o przyjsciu nowego
//    2) stawia nowy proces dziecko %WebRTC.Endpoint{}, linkuje se pady idkiem tracka itd
//    2) powoduje to strigerowanie restartu ajsa
//  issue:
//     czy jest tu mozliwe raise costam, gdyby 3) wykonalo sie przed 1)?
//     otusz nie, bo wiadomosc do RoomChannela idzie tylko przez pipeline, to endpoint notyfikuje pipeline ws. signallingu -> pipeline wysyla odpowiednie wiadomosci do roomchanela -> itd.

// notyfikuje innych peerow oraz wysyla klientowi liste participantow, którą moze sobie przechwycić klinet nie tylko w WebRTC
// powstaje
// jest odpalany SDP singalling

//
// narazie wsadź wszystko do room.ts, potem se wydziel co najwyzej costam do osobnej klasy
//

//
// teraz jest pytanie, bo:
//  obecnei webrtc config jest pchany do serwera przy joinie
//  w ogóle gdzie są te rzeczy configowe, bo to wygląda jakby params w join() w chanellu == MembraneWebRTCConfig.participant Config, ale czemu to nie jest caly config xd?
//  ok, bo tam rzeczywiscie jest pchany tylko participantConfig

// robie na branchu commit "wip", potem go z-soft-deletuje

// czy obecnie update listy participantow leci do wszystkich przy starcie, czy przy joinie nowego typa?
// leci to na :new_peer, czyli na "start"

// w webrtc this.socket jest uzywane do
//   - wziecia chanellu (uzywajac participant configa i channelId)
//   - dodania onError oraz onClose
//   - wyczyszczenia potem tych referencji

//  caly

// ok to po moim refactorze
// podczas join w roomchannelu jest tworzone participant_id i wysylane do klienta
// displayname, relaymedia, participant type jest wysylane dopiero na start
// nazwa pokoju nie jest zmieniana

// dodalem tworzenei idika na poczatku
