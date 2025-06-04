// MQTTSettingsManager.swift
//
// A blend of human creativity by TheMisfit68 and
// AI assistance from ChatGPT.
// Crafting the future, one line of Swift at a time.
// Copyright © 2023 Jan Verrept. All rights reserved.

import Foundation
import MQTTNIO
import OSLog
import JVSecurity
import JVSwiftCore

/// The MQTTConfiguration class is responsible for configuring the MQTT client
/// Uses the serverCredentials from the keychain to setup the connection
open class MQTTSettingsManager:Configurable, Securable, Loggable {
	public var notificationKey: String = "MQTTClientSettingsChanged"
	
	public var host: String
	public var portNumber: Int
	public var configuration: MQTTClient.Configuration
	
	public init() {
		self.host = ""
		self.portNumber = 8883 // Default MQTT port for SSL/TLS
		self.configuration = MQTTClient.Configuration()
		reloadSettings()
	}
	
	
	public func reloadSettings(){
		
		// Read the credentials
		let serverCredentials = serverCredentialsFromKeyChain(name: "MQTTClient", location: "be.oneclick.MQTTClient")
		if let host = serverCredentials?.server,
		   let port = serverCredentials?.port,
		   let userName = serverCredentials?.account,
		   let password = serverCredentials?.password {
			
			self.host = host
			self.portNumber = port
			
			let tlsConfig = TSTLSConfiguration()
			self.configuration = MQTTClient.Configuration( version: .v5_0,
														   disablePing: true,
														   keepAliveInterval: .seconds(90),
														   pingInterval: nil,
														   connectTimeout: .seconds(10),
														   timeout: nil,
														   userName: userName,
														   password: password,
														   useSSL: true,
														   useWebSockets: false,
														   tlsConfiguration:.ts(tlsConfig),
														   sniServerName: nil
			)
		}
	}
}
