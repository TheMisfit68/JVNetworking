// JVMQTTClient.swift
//
// A blend of human creativity by TheMisfit68 and
// AI assistance from ChatGPT.
// Crafting the future, one line of Swift at a time.
// Copyright © 2023 Jan Verrept. All rights reserved.

import Foundation
import CocoaMQTT
import OSLog
import JVSecurity
import JVSwiftCore


/// Wrapper around CocoaMQTT
/// Uses the serverCredentials from the keychain to setup the connection
open class MQTTClient: Configurable, Securable, Loggable {
	
	public var notificationKey: String = "MQTTClientSettingsChanged"
	
	private let autoSubscriptions:[String]?
	private let autoPublications:[String]?
	private let clientID:String
	private var host:String
	private var port:Int
	private var isConnected:Bool
	
	lazy private var mqtt: CocoaMQTT5 = CocoaMQTT5(clientID: clientID, host: "\(self.host)", port: UInt16(self.port))
	private var connectionProperties: MqttConnectProperties {
		let connectProperties = MqttConnectProperties()
		connectProperties.topicAliasMaximum = 0
		connectProperties.sessionExpiryInterval = 0
		connectProperties.receiveMaximum = 100
		connectProperties.maximumPacketSize = 500
		return connectProperties
	}
	
	public init(name clientID:String, autoSubscribeTo autoSubscriptions:[String]? = nil, autoPublishTo autoPublications:[String]? = nil){
		
		self.autoSubscriptions = autoSubscriptions
		self.autoPublications = autoPublications
		self.clientID = clientID
		self.host = ""
		self.port = 0
		self.isConnected = false
		self.reloadSettings()
		
	}
	
	public func reloadSettings(){
		
		// Read the credentials
		let serverCredentials = serverCredentialsFromKeyChain(name: "MQTTClient", location: "be.oneclick.MQTTClient")
		if let host = serverCredentials?.server, let port = serverCredentials?.port, let userName = serverCredentials?.account, let password = serverCredentials?.password {
			
			if isConnected {
				disconnect()
			}
			self.host = host
			self.port = port
						
			mqtt.username = userName
			mqtt.password = password
			mqtt.autoReconnect = true
			mqtt.enableSSL = true
			mqtt.willMessage = CocoaMQTT5Message(topic: "/will", string: "dieout")
			mqtt.delegate = self
			mqtt.keepAlive = 60

			mqtt.connectProperties = self.connectionProperties
		}
	}
	
	public func connect() {
		isConnected = mqtt.connect()
		
		if isConnected {
			MQTTClient.logger.info("🔗\tConnecting successful")
		} else {
			MQTTClient.logger.error("❌\tConnecting failed") // Log error level message
		}
	}
	
	public func disconnect(){
		mqtt.disconnect()
		isConnected = false
		MQTTClient.logger.info("❌\tDisconnected")
	}
	
	
	// MARK: - Publishing
	public func publish<T: Encodable>(topic: String, type jsonEncodableType: T, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) {
		if let jsonPayloadString = jsonEncodableType.stringValue {
			publish(topic:topic, message: jsonPayloadString, qos: qos, retained: retained)
		}
	}
	
	public func publish(topic:String? = nil, message: String, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) {
		
		if let topic = topic{
			mqtt.publish(topic, withString: message, qos: qos, retained: retained, properties: MqttPublishProperties())
			MQTTClient.logger.info("🗯️\tPublished message to topic: \(topic)")
		}else{
			autoPublications?.forEach {
				if $0 != topic{
					mqtt.publish($0, withString: message, qos: qos, retained: retained, properties: MqttPublishProperties())
					MQTTClient.logger.info("🗯️\tPublished message to topic: \($0)")
				}
			}
		}
	}
	
	// MARK: - Subscription
	public func subscribe(topic: String) {
		MQTTClient.logger.info("👂\tSubscribing to topic: \(topic)")
		mqtt.subscribe(topic)
	}
	
}

extension MQTTClient: CocoaMQTT5Delegate {
	
	// Connection and Disconnection-events
	public func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
		if ack == .success{
			self.autoSubscriptions?.forEach {
				subscribe(topic: $0)
			}
			publish(message:"Client \(clientID) did connect")
		}
	}
	
	public func mqtt5DidDisconnect(_ mqtt5:CocoaMQTT5, withError err: (any Error)?) {}
	
	public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {}
	
	public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {}
	
	// Subscribe and Receive events
	public func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {}
	
	public func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {}
	
	public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
		let topic = message.topic
		let message = String(bytes: message.payload, encoding: .utf8) ?? "Invalid UTF8 data"
		MQTTClient.logger.info("🗯️\tReceived message on \(topic):\n\t\(message)")
	}
	
	
	
	// publishing events
	public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {}
	
	public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {}
	
	public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {}
	
	
	// Ping and Pong-events
	
	public func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {}
	
	public func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {}
	
	
}
