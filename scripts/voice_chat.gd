class_name BidVoiceChat
extends Node

signal signal_requested(peer_id: int, message: Dictionary)
signal status_changed(status: String)

var callback_ref: JavaScriptObject
var initialized := false
var local_peer_id := 0
var peer_ids: Array[int] = []

const VOICE_JS := """
(function () {
  const state = window.__bidVoice || (window.__bidVoice = { pcs: {}, pending: {}, stream: null, rawStream: null, audioContext: null, gainNode: null, micGain: 1, muted: false, enabled: false, localId: 0, peers: [], peerMuted: {}, peerVolume: {} });
  state.micGain = state.micGain || 1;
  state.generation = (state.generation || 0) + 1;
  const generation = state.generation;
  const send = (to, message) => { if (generation === state.generation && window.bidVoiceSignalOut) window.bidVoiceSignalOut(JSON.stringify({ to, message })); };
  const closeAudio = (peer) => { if (peer.audio) { peer.audio.remove(); peer.audio = null; } };
  const createPeer = (remoteId, initiator) => {
    if (state.pcs[remoteId]) return state.pcs[remoteId];
    const pc = new RTCPeerConnection({ iceServers: window.__bidVoiceIceServers || [{ urls: 'stun:stun.l.google.com:19302' }] });
    state.pcs[remoteId] = pc;
    state.pending[remoteId] = state.pending[remoteId] || [];
    if (state.stream) state.stream.getTracks().forEach(track => pc.addTrack(track, state.stream));
    pc.onicecandidate = event => { if (event.candidate) send(remoteId, { type: 'voice-candidate', candidate: event.candidate }); };
    pc.ontrack = event => {
      const stream = event.streams[0];
      let audio = document.querySelector('audio[data-bid-voice="' + remoteId + '"]');
      if (!audio) { audio = document.createElement('audio'); audio.autoplay = true; audio.playsInline = true; audio.dataset.bidVoice = remoteId; document.body.appendChild(audio); }
      audio.srcObject = stream;
      audio.muted = !!state.peerMuted[remoteId];
      audio.volume = state.peerVolume[remoteId] ?? 1;
      audio.play().catch(() => {});
      state.pcs[remoteId].audio = audio;
    };
    pc.onconnectionstatechange = () => { if (['failed', 'closed', 'disconnected'].includes(pc.connectionState)) closeAudio(state.pcs[remoteId]); };
    pc.onnegotiationneeded = async () => {
      if (!state.stream || pc.signalingState !== 'stable') return;
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      send(remoteId, { type: 'voice-offer', sdp: pc.localDescription });
    };
    if (initiator && state.stream) pc.onnegotiationneeded();
    return pc;
  };
  window.bidVoiceConfigure = (localId, peers) => {
    state.localId = Number(localId); state.peers = peers.map(Number).filter(id => id !== state.localId);
    if (!state.stream) return;
    state.peers.forEach(remoteId => createPeer(remoteId, state.localId < remoteId));
  };
  window.bidVoiceToggle = async (localId, peers) => {
    window.bidVoiceConfigure(localId, peers);
    if (!state.stream) {
      try {
        const requestGeneration = state.generation;
        const rawStream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true } });
        if (requestGeneration !== state.generation) { rawStream.getTracks().forEach(track => track.stop()); return 'off'; }
        state.rawStream = rawStream;
        state.audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const source = state.audioContext.createMediaStreamSource(state.rawStream);
        const highpass = state.audioContext.createBiquadFilter(); highpass.type = 'highpass'; highpass.frequency.value = 260;
        const presence = state.audioContext.createBiquadFilter(); presence.type = 'peaking'; presence.frequency.value = 2800; presence.Q.value = 1.1; presence.gain.value = 5;
        const compressor = state.audioContext.createDynamicsCompressor(); compressor.threshold.value = -24; compressor.ratio.value = 5;
        const gain = state.audioContext.createGain(); gain.gain.value = state.micGain; state.gainNode = gain;
        const destination = state.audioContext.createMediaStreamDestination();
        source.connect(highpass).connect(presence).connect(compressor).connect(gain).connect(destination);
        state.stream = destination.stream;
        state.enabled = true; state.muted = false;
        window.bidVoiceConfigure(localId, peers);
        return 'on';
      } catch (error) { return 'denied'; }
    }
    state.muted = !state.muted;
    state.stream.getAudioTracks().forEach(track => track.enabled = !state.muted);
    return state.muted ? 'muted' : 'on';
  };
  window.bidVoiceStop = () => {
    state.generation++;
    Object.values(state.pcs).forEach(pc => {
      pc.ontrack = pc.onicecandidate = pc.onnegotiationneeded = pc.onconnectionstatechange = null;
      closeAudio(pc); pc.close();
    });
    [state.stream, state.rawStream].forEach(stream => { if (stream) stream.getTracks().forEach(track => track.stop()); });
    if (state.audioContext) state.audioContext.close().catch(() => {});
    if (window.speechSynthesis) window.speechSynthesis.cancel();
    state.pcs = {}; state.pending = {}; state.stream = state.rawStream = state.audioContext = state.gainNode = null;
    state.enabled = false; state.muted = false; state.peers = []; state.localId = 0;
    window.bidVoiceSignalOut = null;
  };
  window.bidVoiceAdjustMicGain = (delta) => {
    state.micGain = Math.max(0.5, Math.min(1.8, state.micGain + Number(delta)));
    if (state.gainNode) state.gainNode.gain.value = state.micGain;
    return state.micGain;
  };
  window.bidVoiceTogglePeerMute = (peerId) => {
    const id = Number(peerId); const peer = state.pcs[id];
    state.peerMuted[id] = !state.peerMuted[id];
    if (peer && peer.audio) peer.audio.muted = state.peerMuted[id];
    return state.peerMuted[id];
  };
  window.bidVoiceAdjustPeerVolume = (peerId, delta) => {
    const id = Number(peerId); const peer = state.pcs[id];
    state.peerVolume[id] = Math.max(0, Math.min(1, (state.peerVolume[id] ?? 1) + Number(delta)));
    if (peer && peer.audio) peer.audio.volume = state.peerVolume[id];
    return state.peerVolume[id];
  };
  window.bidVoiceSpeak = (text) => {
    if (!('speechSynthesis' in window)) return;
    const utterance = new SpeechSynthesisUtterance(String(text).slice(0, 80));
    utterance.lang = 'ko-KR'; utterance.rate = 1.16; utterance.pitch = 1.65; utterance.volume = 0.82;
    window.speechSynthesis.cancel(); window.speechSynthesis.speak(utterance);
  };
  window.bidVoiceReceive = async (from, message) => {
    const remoteId = Number(from); const type = message.type; const pc = createPeer(remoteId, false);
    if (type === 'voice-offer') {
      await pc.setRemoteDescription(message.sdp);
      const answer = await pc.createAnswer(); await pc.setLocalDescription(answer);
      send(remoteId, { type: 'voice-answer', sdp: pc.localDescription });
      const queued = state.pending[remoteId] || [];
      for (const candidate of queued) await pc.addIceCandidate(candidate);
      state.pending[remoteId] = [];
    } else if (type === 'voice-answer') {
      await pc.setRemoteDescription(message.sdp);
    } else if (type === 'voice-candidate') {
      if (pc.remoteDescription) await pc.addIceCandidate(message.candidate); else state.pending[remoteId].push(message.candidate);
    }
  };
})();
"""

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	callback_ref = JavaScriptBridge.create_callback(_on_signal_out)
	var window := JavaScriptBridge.get_interface("window")
	window.bidVoiceSignalOut = callback_ref
	var ice_servers: Array = [{"urls": "stun:stun.l.google.com:19302"}]
	var turn_url := str(ProjectSettings.get_setting("bid_network/turn_url", ""))
	if not turn_url.is_empty():
		ice_servers.append({"urls": turn_url, "username": str(ProjectSettings.get_setting("bid_network/turn_username", "")), "credential": str(ProjectSettings.get_setting("bid_network/turn_credential", ""))})
	JavaScriptBridge.eval("window.__bidVoiceIceServers = %s;" % JSON.stringify(ice_servers), true)
	JavaScriptBridge.eval(VOICE_JS, true)
	initialized = true

func _exit_tree() -> void:
	stop()

func stop() -> void:
	if initialized:
		JavaScriptBridge.eval("if (window.bidVoiceStop) window.bidVoiceStop();", true)
	initialized = false
	callback_ref = null

func configure(player_id: int, players: Array) -> void:
	local_peer_id = player_id
	peer_ids.clear()
	for raw_id in players:
		var peer_id := int(raw_id)
		if peer_id != local_peer_id:
			peer_ids.append(peer_id)
	if initialized:
		JavaScriptBridge.eval("window.bidVoiceConfigure(%d,%s);" % [local_peer_id, JSON.stringify(peer_ids)], true)

func toggle() -> void:
	if not initialized:
		status_changed.emit("음성은 웹 HTTPS export에서만 사용할 수 있습니다.")
		return
	var result = JavaScriptBridge.eval("window.bidVoiceToggle(%d,%s);" % [local_peer_id, JSON.stringify(peer_ids)], true)
	if result == "denied":
		status_changed.emit("마이크 권한이 거부되었습니다.")
	else:
		status_changed.emit("MIC ON" if result == "on" else "MIC OFF")

func receive_signal(from_peer_id: int, message: Dictionary) -> void:
	if initialized:
		JavaScriptBridge.eval("window.bidVoiceReceive(%d,%s);" % [from_peer_id, JSON.stringify(message)], true)

func speak_chat(message: String) -> void:
	if initialized:
		JavaScriptBridge.eval("window.bidVoiceSpeak(%s);" % JSON.stringify(message.left(80)), true)

func adjust_mic_gain(delta: float) -> float:
	if not initialized:
		return 1.0
	return float(JavaScriptBridge.eval("window.bidVoiceAdjustMicGain(%f);" % delta, true))

func toggle_peer_mute(peer_id: int) -> bool:
	if not initialized:
		return false
	return bool(JavaScriptBridge.eval("window.bidVoiceTogglePeerMute(%d);" % peer_id, true))

func adjust_peer_volume(peer_id: int, delta: float) -> float:
	if not initialized:
		return 1.0
	return float(JavaScriptBridge.eval("window.bidVoiceAdjustPeerVolume(%d,%f);" % [peer_id, delta], true))

func _on_signal_out(args: Array) -> void:
	if args.is_empty():
		return
	var data = JSON.parse_string(str(args[0]))
	if data is Dictionary and data.has("to") and data.has("message"):
		signal_requested.emit(int(data["to"]), data["message"])
