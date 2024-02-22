//
//  JVURLRequest.swift
//
//
//  Created by Jan Verrept on 17/02/2024.
//

import Foundation
import JVSwiftCore

extension URLRequest:CustomDescriptible {}

public extension CustomDescriptible where Self == URLRequest{
	
	 var customDescription:String{
		
		var logMessage = ""
		
		if let method = self.httpMethod, let url = self.url {
			logMessage += "⤴️\t[\(method)] \(url)\n"
		}
		
		if let headers = self.allHTTPHeaderFields {
			logMessage += "__________________________________________________________________________________________\n"
			
			for (key, value) in headers {
				logMessage += "\(key): \(value)\n"
			}
			logMessage += "__________________________________________________________________________________________\n"
		}
		
		if let bodyData = self.httpBody{
			var bodyString = String(data: bodyData, encoding: .utf8)
			if let contentType = self.value(forHTTPHeaderField: "Content-Type"), contentType.contains("application/x-www-form-urlencoded"){
				bodyString = bodyString?.replacingOccurrences(of: "&", with: "\n")
			}
			logMessage += "\(bodyString ?? "")"
		}
		
		return logMessage
	}
}
