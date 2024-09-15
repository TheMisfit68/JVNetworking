// JVUDPClient.swift
//
// Special thanks to Derik Ramirez (https://rderik.com)
// for his great article on writing a (native) Swift UDP-client,
// adapted with the help of chatGPT.

import Foundation
import Network
import OSLog
import JVSwiftCore

/// An asynchronous UDP client using Swift's modern concurrency features (`async/await`).
///
/// This class provides methods to connect, disconnect, send, and receive data via UDP protocol.
///
/// ## Topics
/// ### Creating a UDP Client
/// - ``init(name:host:port:)``
///
/// ### Managing Connection
/// - ``connect()``
/// - ``disconnect()``
/// - ``reconnect()``
///
/// ### Sending and Receiving Data
/// - ``send(_:)-67ftl``
/// - ``receive(_:)-74w5h``
/// - ``sendRawData(_:)``
/// - ``receiveRawData()``
///
/// ### Connection State Management
/// - ``connectionStateChanged(to:)``
///
/// ### Helper Methods
/// - ``startConnection()``
/// - ``stopConnection()``
///
/// - Important: Ensure your platform supports `NWConnection` (macOS 10.14+).
@available(macOS 10.14, *)
actor UDPClientAsync {
	let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
	
	/// The name of the client.
	public let name: String
	
	/// The hostname of the target server.
	public let hostName: String
	
	/// The port number of the target server.
	public let portName: String
	
	/// The host endpoint for the UDP connection.
	public let host: NWEndpoint.Host
	
	/// The port endpoint for the UDP connection.
	public let port: NWEndpoint.Port
	
	private let udpConnection: NWConnection
	
	/// Initializes a new UDP client.
	///
	/// - Parameters:
	///   - name: A name for the client, used for logging or identification purposes.
	///   - host: The hostname or IP address of the target server.
	///   - port: The port number on the server to which the UDP connection will be made.
	public init(name: String, host: String, port: UInt16) {
		self.name = name
		self.hostName = host
		self.portName = String(port)
		self.host = NWEndpoint.Host(host)
		self.port = NWEndpoint.Port(rawValue: port)!
		self.udpConnection = NWConnection(host: self.host, port: self.port, using: .udp)
		self.udpConnection.stateUpdateHandler = { [weak self] state in
			Task {
				await self?.connectionStateChanged(to: state)
			}
		}
	}
	
	// MARK: - Connection Methods
	
	/// Establishes a UDP connection asynchronously.
	///
	/// - Throws: An error if the connection cannot be established.
	///
	/// - Note: The connection state will be logged upon success.
	public func connect() async throws {
		try await startConnection()
		logger.info("UDP-connection made with @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public)")
	}
	
	/// Terminates the UDP connection.
	///
	/// - Note: The disconnection event will be logged.
	public func disconnect() {
		stopConnection()
		logger.info("UDP-connection closed with @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public)")
	}
	
	/// Reconnects the UDP client by disconnecting and reconnecting.
	///
	/// - Throws: An error if the reconnection process fails.
	public func reconnect() async throws {
		disconnect()
		try await connect()
	}
	
	// MARK: - Sending and Receiving Data
	// Codables
	
	/// Sends encodable data over the UDP connection.
	///
	/// - Parameter decodedData: The data to encode and send.
	/// - Throws: An error if the encoding or sending process fails.
	public func send<T: Encodable>(_ decodedData: T) async throws {
		let rawData:Data = try JSONEncoder().encode(decodedData)
		try await sendRawData(rawData)
	}
	
	/// Receives and decodes data over the UDP connection.
	///
	/// - Parameter type: The type of data to decode.
	/// - Returns: Decoded data of the specified type.
	/// - Throws: An error if receiving or decoding fails.
	public func receive<T: Decodable>(_ type: T.Type) async throws -> T {
		let (rawData, _, _) = try await receiveRawData()
		let decodedData = try JSONDecoder().decode(T.self, from: rawData)
		return decodedData
	}
	
	// Raw Data
	
	/// Sends raw data over the UDP connection.
	///
	/// - Parameter data: The raw data to send.
	/// - Throws: An error if sending the data fails.
	public func sendRawData(_ data: Data) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			udpConnection.send(content: data, completion: .contentProcessed { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					self.logger.info("Data sent to UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public): \(data as NSData, privacy:.public)")
					continuation.resume()
				}
			})
		}
	}
	
	/// Receives raw data over the UDP connection.
	///
	/// - Returns: A tuple containing the data, content context, and a completion flag.
	/// - Throws: An error if receiving the data fails.
	public func receiveRawData() async throws -> (Data, NWConnection.ContentContext?, Bool) {
		return try await withCheckedThrowingContinuation { continuation in
			udpConnection.receiveMessage { data, context, isComplete, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else if let data = data {
					self.logger.info("Data received from UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public): \(data as NSData, privacy:.public)")
					continuation.resume(returning: (data, context, isComplete))
				} else {
					continuation.resume(throwing: UDPClientError.noDataReceived)
				}
			}
		}
	}
	
	// MARK: - Helper methods
	
	/// Starts the UDP connection asynchronously.
	///
	/// - Throws: An error if the connection fails.
	private func startConnection() async throws {
		udpConnection.start(queue: .global())
		try await withCheckedThrowingContinuation { continuation in
			udpConnection.stateUpdateHandler = { state in
				if case .ready = state {
					continuation.resume()
				} else if case .failed(let error) = state {
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	/// Stops the UDP connection.
	private func stopConnection() {
		udpConnection.stateUpdateHandler = nil
		udpConnection.cancel()
	}
	
	// MARK: - Connection State Handling
	
	/// Handles state changes for the UDP connection.
	///
	/// - Parameter state: The new state of the connection.
	private func connectionStateChanged(to state: NWConnection.State) {
		switch state {
			case .waiting(let error):
				logger.error("UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public) waiting with error: \(error.localizedDescription)")
			case .ready:
				logger.info("UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public) ready")
			case .failed(let error):
				logger.error("UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public) did fail with error: \(error.localizedDescription)")
				stopConnection()
			default:
				break
		}
	}
	
}

/// Custom error types for `UDPClientAsync`.
enum UDPClientError: Error {
	/// Error indicating that no data was received.
	case noDataReceived
}
