//
//  JVPinger.swift
//  
//
//  Created by Jan Verrept on 04/06/2021.
//

import Foundation
import RegexBuilder
import OSLog
import JVScripting
import JVSwiftCore

public class Pinger{
		
	public init(){}
	
	public func ping(_ host:String, numberOfPings:Int =  1, timeOut:TimeInterval = 2.0)->String{
		
		let pingCommand:TerminalCommand = TerminalCommand("ping -c \(numberOfPings) -W \(timeOut) \(host)")
        
        do{
            let pingResult:String = try pingCommand.execute()
            return pingResult
        }catch{
            let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "Pinger")
            logger.error("\(error.localizedDescription)")
            return ""
        }
        
	}
	
	public func ping(_ host:String, numberOfPings:Int = 1, timeOut:TimeInterval = 2.0, maxresponseTime:TimeInterval = 1.0)->Bool{
		
		let pingresult:String = ping(host, numberOfPings: numberOfPings, timeOut: timeOut)
		        
        let regexPattern = /(?<maxTime>\d\.\d{3})\/(?:\d\.\d{3}\/?)\sms$/.ignoresCase()
        if let responseText = pingresult.firstMatch(of: regexPattern), let responseTime = TimeInterval(responseText.maxTime){
            let responseTimeInms = responseTime/1000
            return responseTimeInms <= maxresponseTime
		}else{
			return false
		}
	}
	
	
}
