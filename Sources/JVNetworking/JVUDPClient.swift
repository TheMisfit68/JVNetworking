// Special thanks to Derik Ramirez (https://rderik.com)
// for his great article on writing a (native) Swift UDP-client

import Foundation
import Network
import OSLog

@available(macOS 10.14, *)
open class UDPClient {
	
	public let name: String
    public let hostName: String
    public let portName: String
	public let host: NWEndpoint.Host
	public let port: NWEndpoint.Port
	public var dataReceiver:((Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)? = nil
	private let dummyReceiver:((Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void) = { _,_,_,_ in }
	private let maxUDPPackageSize = 65535 //The UDP maximum package size is 64K
	private let udpConnection: NWConnection
	
	let queue = DispatchQueue(label: "UDP-client connection events Q")
	
	public init(name: String, host: String, port: UInt16){
		self.name = name
        self.hostName = host
        self.portName = String(port)
		self.host = NWEndpoint.Host(host)
		self.port = NWEndpoint.Port(rawValue: port)!
		self.udpConnection = NWConnection(host: self.host, port: self.port, using: .udp)
		self.udpConnection.stateUpdateHandler = self.connectionStateChanged(to:)
	}
	
	public func connect() {
		udpConnection.start(queue: queue)
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
        logger.info("UDP-connection made with @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public)")
	}
	
	public func disconnect() {
		stop(error: nil)
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
        logger.info("UDP-connection closed with @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public)")
	}
	
	public func reconnect() {
		disconnect()
		connect()
	}
	
	public func send(data: Data) {
		
		if let dataReceiver = self.dataReceiver {
			udpConnection.receiveMessage(completion: dataReceiver)
		}else{
			udpConnection.receiveMessage(completion: dummyReceiver)
		}
		
		udpConnection.send(content: data, completion: .contentProcessed( { error in
			if let error = error {
				self.connectionDidFail(error: error)
				return
			}
		}))
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
        logger.info("Data sent to UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public): \(data as NSData, privacy:.public)")
	}
	
	
	// MARK: - Connection event handlers
    private func connectionStateChanged(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
            logger.info("UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
	private func connectionDidFail(error: Error) {
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
        logger.error("UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public) did fail, error: \(error)")
		self.stop(error: error)
	}
	
	private func connectionDidEnd() {
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVUDPClient")
        logger.info("UDP-connection @IP \(self.hostName, privacy: .public): \(self.portName, privacy: .public) did end")
		self.stop(error: nil)
	}
	
	// MARK: - Subroutines
	private func stop(error: Error?) {
		udpConnection.stateUpdateHandler = nil
		udpConnection.cancel()
	}
	
	
}
