//
//  JVWebSocket.swift
//
//
//  Created by Jan Verrept on 28/02/2020.
//
import Foundation
import JVSwiftCore

@available(OSX 10.15, *)
public protocol WebSocketDelegate{
    func connected()
    func disconnected(error: Error?)
    func received(text: String)
    func received(data: Data)
    func received(error: Error)
}

@available(OSX 10.15, *)
public class WebSocket:NSObject, URLSessionWebSocketDelegate {
    
    var urlSession:URLSession!
    var webSocketTask:URLSessionWebSocketTask!
    var webSocketDelegate:WebSocketDelegate?
    
    public init(urlRequest:URLRequest, delegate:WebSocketDelegate?){
        super.init()
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        webSocketTask = urlSession.webSocketTask(with:urlRequest)
        self.webSocketDelegate = delegate
		
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.webSocketDelegate?.connected()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.webSocketDelegate?.disconnected(error:nil)
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Pass test server with self signed certificate
		if let trustedHost = webSocketTask.currentRequest?.url?.host, challenge.protectionSpace.host == trustedHost {
            completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
        
    }
    
    public func connect() {
        webSocketTask.resume()
        listen()
    }
    
    public func disconnect() {
        webSocketTask.cancel(with: .goingAway, reason: nil)
    }
    
    
    public func send(text: String) {
        let message:URLSessionWebSocketTask.Message = .string(text)
        webSocketTask.send(message) { error in
            if let error = error {
                self.webSocketDelegate?.received(error: error)
            }
        }
    }
    
    public func send(data: Data) {
        let message:URLSessionWebSocketTask.Message = .data(data)
        webSocketTask.send(message) { error in
            if let error = error {
                self.webSocketDelegate?.received(error: error)
            }
        }
    }
    
    public func ping() {
        webSocketTask.sendPing { error in
            if let error = error {
                self.webSocketDelegate?.received(error: error)
            }
        }
    }
    
    private func listen()  {
        
        webSocketTask.receive { result in
            switch result {
                
            case .success(let message):
                
                switch message {
                case .string(let text):
                    self.webSocketDelegate?.received(text: text)
                case .data(let data):
                    self.webSocketDelegate?.received(data: data)
                @unknown default:
                    fatalError()
                }
                self.listen()
                
            case .failure(let error):
                self.webSocketDelegate?.received(error: error)
                
            }
        }
    }
    
}
