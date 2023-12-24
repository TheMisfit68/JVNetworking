    //
    //  JVRestAPI.swift
    //
    //
    //  Created by Jan Verrept on 18/04/2020.
    //

import Foundation
import OSLog
import JVSwiftCore

@available(macOS 12.0.0, *)
public class RestAPI<E:StringRepresentableEnum, P:StringRepresentableEnum>{
    
    public enum Method:String {
        case GET
        case POST
        case PUT
        case DELETE
    }
    
    public enum Error: Swift.Error {
        case statusError
        case decodingError
    }
    
    public var baseURL:String
    public var endpointParameters:[E:[P]]
    public var baseValues:[P:String]
    
    public init(baseURL:String, endpointParameters:[E:[P]], baseValues:[P:String] = [:]){
        
        self.baseURL = baseURL
        self.endpointParameters = endpointParameters
        self.baseValues = baseValues
        
    }
    
    public func decode<T:Decodable>(method:RestAPI.Method = .GET, using decoder:JSONDecoder = newJSONDecoder(), command:E, parameters:[P:String]) async throws -> T?{
        
        let form = HTTPForm(parametersToInclude: endpointParameters[command] ?? [], currentParameters: parameters)
        
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVRestApi")
        
        logger.info(
        """
        🔃\tDecoding [\(method.rawValue, privacy: .public)] \(self.baseURL, privacy:.public)\(command.rawValue, privacy:.public)
        \(form.description, privacy:.public)
        """
        )
        
        switch method{
        case .GET:
            guard let data = try? await get(command: command, parameters: parameters) else { throw Error.statusError }
            guard let decodedData = try? decoder.decode(T.self, from: data) else { throw Error.decodingError}
            return decodedData
        case .POST:
            guard let data = try? await post(command: command, parameters: parameters) else { throw Error.statusError }
            print("🐞\t\(String(decoding: data, as: UTF8.self))")
            guard let decodedData = try? decoder.decode(T.self, from: data) else { throw Error.decodingError}
            return decodedData
        default:
#warning("TODO") // TODO: - Complete RestAPI
            return nil
        }
        
    }
    
    public func get(command:E, parameters:[P:String]) async throws -> Data?{
        
        let parameters = baseValues.merging(parameters) {$1}
        let form = HTTPForm(parametersToInclude: endpointParameters[command] ?? [], currentParameters: parameters)
        
        var urlComps = URLComponents(string: baseURL+command.stringValue)
        urlComps?.queryItems = form.urlQueryItems
        let url:URL? = urlComps?.url
        
        var request:URLRequest! = URLRequest(url: url!)
        request.httpMethod = Method.GET.rawValue
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(statusCode)  else {
            throw Error.statusError
        }
        
        let dataString = String(decoding: data, as: UTF8.self)
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVRestApi")
        logger.info("↩️\tReceived data for [GET] \(command.stringValue, privacy: .public):\n\(dataString, privacy: .public)")

        return data
    }
    
    public func post(command:E, parameters:[P:String]) async throws -> Data?{
        
        let parameters = baseValues.merging(parameters) {$1}
        let form = HTTPForm(parametersToInclude: endpointParameters[command] ?? [], currentParameters: parameters)
        
        let  url = URL(string:baseURL+command.stringValue)
        
        var request = URLRequest(url: url!)
        request.httpMethod = Method.POST.rawValue
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = ["Content-Type" : "application/x-www-form-urlencoded"]
        request.httpBody = form.composeBody(type: .FormEncoded)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(statusCode)  else {
            throw Error.statusError
        }
        
        let dataString = String(decoding: data, as: UTF8.self)
        let logger = Logger(subsystem: "be.oneclick.JVSwift", category: "JVRestApi")
        logger.info("↩️\tReceived data for [POST] \(command.stringValue, privacy: .public):\n\(dataString, privacy: .public)")
                
        return data
    }

}

public struct HTTPForm<P:StringRepresentableEnum>{
    
    private var stringRepresentations:[(String, String)]
    private var parametersAndValues:[String]
    public var urlQueryItems:[URLQueryItem]
    
    public var description:String{
        parametersAndValues.joined(separator: "\n")
    }
    
    public enum HTTPbodyType{
        case Json
        case FormEncoded
    }
    
    public init(parametersToInclude:[P], currentParameters:[P:String]){
        
        let filteredParameters = currentParameters.filter   {(parameterName, parameterValue) in parametersToInclude.contains(parameterName)}
        
        self.stringRepresentations = filteredParameters.map  {(parameterName, parameterValue) in (parameterName.stringValue, Self.Encode(parameterValue))}
        self.parametersAndValues = stringRepresentations.map {parameterName, parameterValue in  "\(parameterName)=\(parameterValue)" }
        
        self.urlQueryItems = filteredParameters.map{ (parameterName, parameterValue) in URLQueryItem(name: parameterName.stringValue, value: parameterValue)}
    }
    
    public static func Encode(_ parameter:String)->String{
        
        var encodedParameter = parameter
        encodedParameter = encodedParameter.replacingOccurrences(of: ",", with: "%2C")
        encodedParameter = encodedParameter.replacingOccurrences(of: " ", with: "%20")
        encodedParameter = encodedParameter.replacingOccurrences(of: "/", with: "%2F")
        encodedParameter = encodedParameter.replacingOccurrences(of: "+", with: "%2B")
        encodedParameter = encodedParameter.replacingOccurrences(of: "=", with: "%3D")
        
        return encodedParameter
    }
    
    
    public func composeBody(type:HTTPbodyType = .Json)->Data?{
        
        switch type {
        case .Json:
            return try? JSONSerialization.data(withJSONObject: stringRepresentations, options: .prettyPrinted)
        case .FormEncoded:
            return parametersAndValues.joined(separator: "&").data(using: .utf8)
        }
        
    }
    
}
