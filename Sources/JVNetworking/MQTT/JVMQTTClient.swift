// JVMQTTClient.swift
//
// A blend of human creativity by TheMisfit68 and
// AI assistance from ChatGPT.
// Crafting the future, one line of Swift at a time.
// Copyright © 2023 Jan Verrept. All rights reserved.

import Foundation
import CocoaMQTT
import OSLog

open class MQTTClient {
	private var mqtt: CocoaMQTT!
	private let logger = Logger(subsystem: "Test", category: "MQTT") // Create an OSLog object
	
	public init() {
		let clientID = "TheHAPINestServer"
		mqtt = CocoaMQTT(clientID: clientID, host: "localhost", port: 1883)
		mqtt.delegate = self
		mqtt.keepAlive = 60
	}
	
	public func connect() {
		let isConnected = mqtt.connect()
		
		if isConnected {
			logger.info("Connecting successful") // Log info level message
		} else {
			logger.error("Connecting failed") // Log error level message
		}
	}
	
	public func publish(topic: String, message: String) {
		mqtt.publish(topic, withString: message)
		logger.info("Published message to topic: \(topic)") // Log info level message
	}
	
	public func subscribe(topic: String) {
		logger.info("Subscribin to topic: \(topic)") // Log info level message
		mqtt.subscribe(topic)
	}
}

extension MQTTClient: CocoaMQTTDelegate {
	
	public func mqttDidPing(_ mqtt: CocoaMQTT) {
		logger.info("MQTT did ping")
	}
	
	public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
		logger.info("MQTT did receive pong")
	}
	
	func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int) {
		logger.info("connected to \(host) on port \(port)")
	}
	
	public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
		self.subscribe(topic: "ToServer")
		if ack == .accept {
		}
		logger.info("MQTT did receive connection acknowledgement: \(ack)")
	}
	
	public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
		logger.info("did publish message with id \(id)")
	}
	
	public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
		logger.info("did publish ack with id \(id)")
	}
	
	public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
		logger.info("did receive message with id \(id):\n\(message.string!)")
		self.publish(topic: "FromServer", message: "I heard you loud and clear:\nmessage:\(message.string!)")
	}
	
	func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String, messageID: UInt16) {
		logger.info("did subscribe to topic \(topic)")
	}
	
	public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
		logger.info("did subscribe to topics")
	}
	
	func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
		logger.info("did unsubscribe from topic \(topic)")
	}
	
	public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
		logger.info("did unsubscribe from topics \(topics)")
	}
	
	public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
		logger.error("mqtt did disconnect \(err)")
		
		// Attempt to reconnect after 5 seconds
		DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
			let _ = self.connect()
		}
	}
}
