//
//  JVRestAPI.swift
//
//
//  Created by Jan Verrept on 18/04/2020.
//

import Foundation
import OSLog
import JVSwiftCore

/// A class to handle REST API requests
@available(macOS 12.0.0, *)
public class RestAPI{
	let logger = Logger(subsystem: "be.oneclick.JVNetworking", category: "JVRestApi")
	
	
	public enum Method:String {
		case GET
		case POST
		case PUT
		case DELETE
	}
	
	public var baseURL:String
	
	public init(baseURL:String){
		
		self.baseURL = baseURL
		
	}
	
	/// A method to decode a response from a REST API
	/// The object to decode should also be encodable so it can be printed out as a JSON encoded string,
	/// hence the conformation to Codable
	public func decode<T:Codable>(method:RestAPI.Method = .GET,
								  command:any StringRepresentableEnum,
								  parameters:HTTPFormEncodable? = nil,
								  includingBaseParameters baseParameters: HTTPFormEncodable? = nil,
								  timeout: TimeInterval = 10) async throws -> T?{
		
		var decodedObject:T?
		switch method{
			case .GET:
				guard let data = try? await get(command: command, parameters: parameters, includingBaseParameters: baseParameters, timeout:timeout) else {
					throw URLError(.badServerResponse)
				}
				guard let objectFromData = T(from: data, dateDecodingStrategy: .iso8601)  else {
					throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Failed to decode data"))
				}
				decodedObject = objectFromData
			case .POST:
				guard let data = try? await post(command: command, parameters: parameters, includingBaseParameters: baseParameters, timeout:timeout) else {
					throw URLError(.badServerResponse)
				}
				guard let objectFromData = T(from: data, dateDecodingStrategy: .iso8601)  else {
					throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Failed to decode data"))
				}
				decodedObject = objectFromData
			default:
				// TODO: - Complete RestAPI
				return nil
		}
		
		logger.debug(
"""
⤵️\t[\(method.rawValue)] Received data for \(command.stringValue, privacy: .public):
\(decodedObject.debugDescription, privacy: .public)
"""
		)
		return decodedObject
		
	}
	
	
	public func get(command:any StringRepresentableEnum,
					parameters:HTTPFormEncodable? = nil,
					includingBaseParameters baseParameters: HTTPFormEncodable? = nil,
					timeout: TimeInterval = 10) async throws -> Data?{
		
		guard var urlComponents = URLComponents(string: self.baseURL) else { throw URLError(.badURL) }
		urlComponents.path += command.rawValue
		urlComponents.queryItems = HTTPForm(baseParameters: baseParameters, parameters: parameters).asQueryItems()
		guard let url = urlComponents.url else { throw URLError(.badURL) }
		
		var request:URLRequest = URLRequest(url: url)
		request.httpMethod = Method.GET.rawValue
		request.timeoutInterval = timeout
		
		logger.info("\(request.description)")
		
		let (data, response) = try await URLSession.shared.data(for: request)
		let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // 500 Internal Server Error in case of nil
		guard (200...299).contains(httpStatusCode) else {
			logger.debug("⤵️\t[\(RestAPI.Method.GET.rawValue)] No data received for \(command.stringValue, privacy: .public)")
			throw URLError(.badServerResponse)
		}
		
		return data
		
	}
	
	public func post(command:any StringRepresentableEnum,
					 parameters:HTTPFormEncodable? = nil,
					 includingBaseParameters baseParameters: HTTPFormEncodable? = nil,
					 timeout: TimeInterval = 10) async throws -> Data?{
		
		guard var urlComponents = URLComponents(string: self.baseURL) else { throw URLError(.badURL) }
		urlComponents.path += command.rawValue
		urlComponents.queryItems = nil
		guard let url = urlComponents.url else { throw URLError(.badURL) }
		
		var request = URLRequest(url: url)
		request.httpMethod = Method.POST.rawValue
		request.timeoutInterval = timeout
		request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		
		if let body = HTTPForm(baseParameters: baseParameters, parameters: parameters).urlEncoded(){
			request.httpBody = body.data
			request.setValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")
		}
		
		logger.info("\(request.description)")
		
		let (data, response) = try await URLSession.shared.data(for: request)
		let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 500 // 500 Internal Server Error in case of nil
		guard (200...299).contains(httpStatusCode) else {
			logger.debug("⤵️\t[\(RestAPI.Method.POST.rawValue)] No data received for \(command.stringValue, privacy: .public)")
			throw URLError(.badServerResponse)
		}
		
		return data
	}
	
}

public protocol HTTPFormEncodable: Encodable {
	// Protocol extension for Encodable
	func asQueryItems() throws -> [URLQueryItem]
}

public extension HTTPFormEncodable {
	
	func asQueryItems() throws -> [URLQueryItem] {
		let encoder = JSONEncoder()
		let data = try encoder.encode(self)
		
		guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
			throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "Failed to convert encoded data to dictionary"))
		}
		
		return dictionary.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
	}
	
}

struct HTTPForm {
	
	let baseParameters: HTTPFormEncodable?
	let parameters: HTTPFormEncodable?
	
	// Properties as a one-dimensional array of URLQueryItem
	func asQueryItems() -> [URLQueryItem] {
		var queryItems: [URLQueryItem] = []
		
		if let baseItems = try? baseParameters?.asQueryItems() {
			queryItems += baseItems
		}
		
		if let remainingItems = try? parameters?.asQueryItems() {
			queryItems += remainingItems
		}
		
		return queryItems
	}
	
	// Properties as single JSON object
	func asJSON() -> (Data, contentLength:String)? {
		
		let queryItems = self.asQueryItems()
		guard let jsonData = try? JSONSerialization.data(withJSONObject: queryItems, options: [])else{return nil}
		return (jsonData, "\(jsonData.count)")
	}
	
	// Properties as form URL-encoded Form
	private func percentEncode(_ value: String) -> String {
		
		let charactersToEncode = CharacterSet(charactersIn: ", /+=@")
		let percentEncodedValue = value.addingPercentEncoding(withAllowedCharacters: charactersToEncode.inverted) ?? ""
		
		return percentEncodedValue
		
	}
	
	
	func urlEncoded() -> (data:Data, contentLength:String)? {
		let queryItems = self.asQueryItems()
		
		// Construct the query string manually with original key case and URL-encoded values
		let queryString = queryItems.map {
			"\($0.name)=\(percentEncode($0.value ?? "") )"
		}.joined(separator: "&")
		
		guard let body = queryString.data(using: .utf8)else{return nil}
		return (data:body, contentLength:"\(body.count)")
		
	}
	
}
