//
//  JVHTTPStatusCode.swift
//
//
//  Created by Jan Verrept on 21/12/2023.
//

import Foundation

public enum HTTPStatusCode: Int {
	case ok = 200
	case created = 201
	case accepted = 202
	case noContent = 204
	case badRequest = 400
	case unauthorized = 401
	case forbidden = 403
	case notFound = 404
	case methodNotAllowed = 405
	case conflict = 409
	case internalServerError = 500
	case notImplemented = 501
	case serviceUnavailable = 503
	// Add other status codes as needed
	
	var description: String {
		switch self {
		case .ok: return "OK"
		case .created: return "Created"
		case .accepted: return "Accepted"
		case .noContent: return "No Content"
		case .badRequest: return "Bad Request"
		case .unauthorized: return "Unauthorized"
		case .forbidden: return "Forbidden"
		case .notFound: return "Not Found"
		case .methodNotAllowed: return "Method Not Allowed"
		case .conflict: return "Conflict"
		case .internalServerError: return "Internal Server Error"
		case .notImplemented: return "Not Implemented"
		case .serviceUnavailable: return "Service Unavailable"
		}
	}
}
