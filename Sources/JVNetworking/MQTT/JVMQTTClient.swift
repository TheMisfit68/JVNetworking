// JVMQTTClient.swift
//
// A blend of human creativity by TheMisfit68 and
// AI assistance from ChatGPT.
// Crafting the future, one line of Swift at a time.
// Copyright © 2023 Jan Verrept. All rights reserved.

import Foundation
import CocoaMQTT
import OSLog
import JVSwiftCore
import JVSecurity

/// Wrapper around CocoaMQTT
/// Uses the serverCredentials from the keychain to setup the connection
open class MQTTClient: Configurable, Securable {
	
	private let logger = Logger(subsystem: "be.oneclick.jan.JVNetworking", category: "MQTTClient") // Create an OSLog object
	public var notificationKey: String = "MQTTClientSettingsChanged"
	
	private let autoSubscriptions:[String]?
	private let autoPublications:[String]?
	private let clientID:String
	private var host:String
	private var port:Int
	private var isConnected:Bool
	
	lazy private var mqtt: CocoaMQTT = CocoaMQTT(clientID: clientID, host: "\(self.host)", port: UInt16(self.port))
	
	
	public init(autoSubscribeTo autoSubscriptions:[String]? = nil, autoPublishTo autoPublications:[String]? = nil){
		
		self.autoSubscriptions = autoSubscriptions
		self.autoPublications = autoPublications
		self.clientID = "TheHAPINestServer"
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
			mqtt.enableSSL = true
			mqtt.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
			mqtt.delegate = self
			mqtt.keepAlive = 60			
		}
	}
	
	public func connect() {
		isConnected = mqtt.connect()
		
		if isConnected {
			logger.info("🔗\tConnecting successful")
		} else {
			logger.error("❌\tConnecting failed") // Log error level message
		}
	}
	
	public func disconnect(){
		mqtt.disconnect()
		isConnected = false
		logger.info("❌\tDisconnected")
	}
	
	
	// MARK: - Publishing
	public func publish<T: Encodable>(topic: String, type jsonEncodableType: T, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) {
		if let jsonPayloadString = generateJSONPayload(from: jsonEncodableType) {
			publish(topic:topic, message: jsonPayloadString, qos: qos, retained: retained)
		}
	}
	
	public func publish(topic:String? = nil, message: String, qos: CocoaMQTTQoS = .qos1, retained: Bool = false) {
		
		if let topic = topic{
			mqtt.publish(topic, withString: message, qos: qos, retained: retained)
			logger.info("🗯️\tPublished message to topic: \(topic)")
		}else{
			autoPublications?.forEach {
				if $0 != topic{
					mqtt.publish($0, withString: message, qos: qos, retained: retained)
					logger.info("🗯️\tPublished message to topic: \($0)")
				}
			}
		}
	}
	
	// MARK: - Subscription
	public func subscribe(topic: String) {
		logger.info("👂\tSubscribing to topic: \(topic)")
		mqtt.subscribe(topic)
	}
	
	
	// MARK: - JSON support
	func generateJSONPayload<T: Encodable>(from jsonEncodableType: T) -> String? {
		do {
			let jsonData = try JSONEncoder().encode(jsonEncodableType)
			return String(data: jsonData, encoding: .utf8)
		} catch {
			logger.error("Unable to generate JSON Payload from Type")
			return nil
		}
	}
	
	
}

extension MQTTClient: CocoaMQTTDelegate {
	
	
	// Connection and Disconnection-events
	public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck){
		if ack == .accept{
			self.autoSubscriptions?.forEach {
				subscribe(topic: $0)
			}
			publish(message:"Client \(clientID) did connect")
		}
	}
	
	public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {}
	
	
	// Subscribe and Receive events
	public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
	
	public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
	
	public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ){
		let topic = message.topic
		let message = String(bytes: message.payload, encoding: .utf8) ?? "Invalid UTF8 data"
		logger.info("🗯️\tReceived message on \(topic):\n\t\(message)")
	}
	
	
	// publishing events
	public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16){}
	
	public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16){}
	
	// Ping and Pong-events
	public func mqttDidPing(_ mqtt: CocoaMQTT) {}
	
	public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
	
}
