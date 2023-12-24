//
//  JVRESTServer.swift
//
//
//  Created by Jan Verrept on 20/12/2023.
//

import Network
import Foundation


/// Very basic implementation of class capable fo receiving REST-commands
/// Uses HTTP instead fo HTTPS and only basic authentication
/// therefore should only be used for testing purposes of IPC (inter Process/Application Communication) and on the local network
open class RESTServer {
	
	let validUsername = "TestUsername"
	let validPassword = "TestPassword"
	
	private let listener: NWListener
	private var queue: DispatchQueue
	public var requestHandler: ((Data) async -> Void)
	
	
	/// In a client project just intialiasing the RESTServer is enough to start it
	/// - Parameter requestHandler: the method that will parse the payload received in the body of the request
	public init(requestHandler: @escaping ((Data) async -> Void)) throws {
		 
		self.listener = try NWListener(using: .tcp, on: 8080)
		
		let queueLabel = "\(Bundle.main.bundleIdentifier ?? "com.unknown").\(String(describing: Self.self))"
		self.queue = DispatchQueue(label: queueLabel)
		
		self.requestHandler = requestHandler
		
		let handleConnection = self.handleConnection
		listener.newConnectionHandler = { connection in
			Task {
				await handleConnection(connection)
			}
		}
		
	}
	
	
	public func start() {
		listener.start(queue: queue)
	}
	
	public func stop() {
		listener.cancel()
	}
	
	private func checkBasicAuth(_ authHeader: String) -> Bool {

		guard let range = authHeader.range(of: "Basic "),
			  let data = Data(base64Encoded: String(authHeader[range.upperBound...])) else {
			return false
		}
		
		let credentials = String(data: data, encoding: .utf8)?.split(separator: ":").map(String.init)
		return credentials?.count == 2 &&
		credentials?[0] == validUsername &&
		credentials?[1] == validPassword
	}
	
	private func handleConnection(_ connection: NWConnection) async {
		connection.start(queue: queue)
		
		do {
			while true {
				let data = try await connection.receiveAsync(minimumIncompleteLength: 1, maximumLength: 65536)
				if let data = data, !data.isEmpty {
					let requestString = String(data: data, encoding: .utf8) ?? ""
					let httpRequest = parseHTTPRequest(requestString)
					
					guard let authHeader = httpRequest.headers["Authorization"],
						  checkBasicAuth(authHeader) else {
						connection.sendResponse(statusCode: .unauthorized)
						return
					}
					
					if let bodyData = httpRequest.body.data(using: .utf8), !bodyData.isEmpty {
						await requestHandler(bodyData)
						connection.sendResponse(statusCode: .ok)
					} else {
						connection.sendResponse(statusCode: .badRequest)
					}
				} else {
					break
				}
			}
		} catch {
			connection.sendResponse(statusCode: .internalServerError)
			connection.cancel()
		}
	}
	
	/// Splits the headers from the actual payload
	/// - Parameter request: the complete request received
	/// - Returns: a tuple of a dictionary (containing the headers) and the body
	private func parseHTTPRequest(_ request: String) -> (headers: [String: String], body: String) {
		let components = request.components(separatedBy: "\r\n\r\n")
		guard components.count >= 2 else {
			return (headers: [:], body: "")
		}
		
		let headersPart = components.first ?? ""
		let bodyPart = components.last!.trimmingCharacters(in: .whitespacesAndNewlines)
		
		var headers = [String: String]()
		let headerLines = headersPart.split(separator: "\r\n")
		for line in headerLines {
			let headerComponents = line.split(separator: ":", maxSplits: 1)
			if headerComponents.count == 2 {
				let key = String(headerComponents[0]).trimmingCharacters(in: .whitespaces)
				let value = String(headerComponents[1]).trimmingCharacters(in: .whitespaces)
				headers[key] = value
			}
		}
		
		return (headers: headers, body: bodyPart)
	}
	
}

extension NWConnection {
	
	/// Provide an async/await style wrapper for NWConnection's receive method
	func receiveAsync(minimumIncompleteLength: Int, maximumLength: Int) async throws -> Data? {
		return try await withCheckedThrowingContinuation { continuation in
			self.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength) { data, _, isComplete, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else if isComplete, data == nil {
					continuation.resume(returning: nil)
				} else {
					continuation.resume(returning: data)
				}
			}
		}
	}
	
	
	/// Sends a response to the client so it doesn't have to time out
	/// - Parameters:
	///   - statusCode: standard statuscodes used with HTTP requests, as defined in the HTTPStatusCode enum
	///   - message: an optional custom message, if the one associated with the statuscode is not sufficient
	func sendResponse(statusCode: HTTPStatusCode, message: String? = nil) {
		let responseMessage = message ?? statusCode.description
		let httpResponse = "HTTP/1.1 \(statusCode.rawValue) \(statusCode.description)\r\n" +
		"Content-Type: text/plain; charset=utf-8\r\n" +
		"Content-Length: \(responseMessage.utf8.count)\r\n\r\n" +
		"\(responseMessage)"
		
		if let data = httpResponse.data(using: .utf8) {
			send(content: data, completion: .contentProcessed({ _ in
				self.cancel()
			}))
		}
	}
}
