//
//  MQTTClientSettingsView.swift
//
//
//  Created by Jan Verrept on 08/11/2023.
//

import SwiftUI
import RegexBuilder
import JVSwiftCore
import JVSecurity
import JVUI


public struct MQTTClientSettingsView:View, SettingsView, Securable{
	
	private let keyChainItemName = "MQTTClient"
	private let hostName:String = ""
	private let portNumber:Int = 0
	private let location:String = "be.oneclick.MQTTClient"
	private let userName:String = ""
	private let password:String = ""
	public let notificationKey:String = "MQTTClientSettingsChanged"
	
	// An explicit public initializer
	public init() {}
	
	public var body: some View {
		
		ServerCredentialsView(keyChainItemName: keyChainItemName, hostName: hostName, portNumber: portNumber, location: location, userName: userName, password: password, notificationKey: notificationKey)
	}
	
}

#Preview {
	MQTTClientSettingsView()
}


