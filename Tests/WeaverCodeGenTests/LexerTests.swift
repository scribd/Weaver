//
//  LexerTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class LexerTests: XCTestCase {
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_type_declaration() {
        
        let file = File(contents: """

            final class MyService {
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0].description, "internal MyService { - 7[19] - at line: 1")
                XCTAssertEqual(tokens[1].description, "_ } - 25[1] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_embedded_type_declaration() {
        
        let file = File(contents: """

            final class MyService {
              final class MyEmbeddedService {
              }
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 4 {
                XCTAssertEqual(tokens[0].description, "internal MyService { - 7[57] - at line: 1")
                XCTAssertEqual(tokens[1].description, "internal MyService.MyEmbeddedService { - 33[29] - at line: 2")
                XCTAssertEqual(tokens[2].description, "_ } - 61[1] - at line: 3")
                XCTAssertEqual(tokens[3].description, "_ } - 63[1] - at line: 4")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_public_type_declaration() {
        
        let file = File(contents: """

            public final class MyService {
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0].description, "public MyService { - 14[19] - at line: 1")
                XCTAssertEqual(tokens[1].description, "_ } - 32[1] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_generic_type_declaration() {
        
        let file = File(contents: """

            public final class MyService<T>: CustomStringDescription {
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0].description, "public MyService<T> { - 14[47] - at line: 1")
                XCTAssertEqual(tokens[1].description, "_ } - 60[1] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_open_type_declaration() {
        
        let file = File(contents: """

            open final class MyService {
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0].description, "open MyService { - 12[19] - at line: 1")
                XCTAssertEqual(tokens[1].description, "_ } - 30[1] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_internal_type_declaration() {
        
        let file = File(contents: """

            internal final class MyService {
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 2 {
                XCTAssertEqual(tokens[0].description, "internal MyService { - 16[19] - at line: 1")
                XCTAssertEqual(tokens[1].description, "_ } - 34[1] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_comment_annotation() {
        
        let file = File(contents: """

            // weaver: api = API <- APIProtocol
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, """
                api = API <- APIProtocol - 1[35] - at line: 1
                """)
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_property_wrapper_annotation() {
        
        let file = File(contents: """

            final class MovieManager {
                
                @Weaver(.registration, type: API.self)
                private var api: APIProtocol
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "api = API <- APIProtocol - 88[20] - at line: 3")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_comment_annotation_and_no_protocol() {
        
        let file = File(contents: """

            // weaver: api = API
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "api = API - 1[20] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_property_wrapper_annotation_and_no_protocol() {
            
            let file = File(contents: """
                final class MovieManager {

                    @Weaver(.registration, type: API.self)
                    private var api: API
                }
                """)
            do {
                let lexer = Lexer(file, fileName: "test.swift")
                let tokens = try lexer.tokenize()
                
                if tokens.count == 3 {
                    XCTAssertEqual(tokens[1].description, "api = API - 83[12] - at line: 2")
                } else {
                    XCTFail("Unexpected amount of tokens: \(tokens.count).")
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_comment_annotation_and_optional_types() {
        
        let file = File(contents: """

            // weaver: api = API? <- APIProtocol?
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "api = Optional<API> <- Optional<APIProtocol> - 1[37] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_property_wrapper_annotation_and_optional_types() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.registration, type: API?.self)
                private var api: APIProtocol?
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "api = Optional<API> <- Optional<APIProtocol> - 84[21] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_comment_annotation_with_generic_types() {
        
        let file = File(contents: """

            // weaver: request = Request<T, P> <- APIRequest<T, P>
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "request = Request<T, P> <- APIRequest<T, P> - 1[54] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_property_wrapper_annotation_with_generic_types() {
            
        let file = File(contents: """
            final class MovieManager<T, P> {

            @Weaver(.registration, type: Request<T, P>.self)
            private var api: APIRequest<T, P>
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "api = Request<T, P> <- APIRequest<T, P> - 91[25] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_comment_annotation_with_generic_and_optional_types() {
        
        let file = File(contents: """

            // weaver: request = Request<T, P>? <- APIRequest<T, P>?
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "request = Optional<Request<T, P>> <- Optional<APIRequest<T, P>> - 1[56] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_register_property_wrapper_annotation_with_generic_and_optional_types() {
        
        let file = File(contents: """
            final class MovieManager<T, P> {

                @Weaver(.registration, type: Request<T, P>?.self)
                private var request: APIRequest<T, P>?
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "request = Optional<Request<T, P>> <- Optional<APIRequest<T, P>> - 100[30] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_comment_annotation() {
        
        let file = File(contents: """

            // weaver: api <- APIProtocol
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "api <- APIProtocol - 1[29] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_property_wrapper_annotation() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.reference)
                private var api: APIProtocol
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "api <- APIProtocol - 64[20] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_comment_annotation_with_an_optional_type() {
        
        let file = File(contents: """

            // weaver: api <- APIProtocol?
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "api <- Optional<APIProtocol> - 1[30] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_property_wrapper_annotation_with_an_optional_type() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.reference)
                private var api: APIProtocol?
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "api <- Optional<APIProtocol> - 64[21] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_comment_annotation_with_a_generic_type() {
        
        let file = File(contents: """

            // weaver: request <- Request<T, P>
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "request <- Request<T, P> - 1[35] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_property_wrapper_annotation_with_a_generic_type() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.reference)
                private var request: Request<T, P>
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "request <- Request<T, P> - 64[26] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_comment_annotation_with_a_generic_optional_type() {
        
        let file = File(contents: """

            // weaver: request <- Request<T, P>?
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "request <- Optional<Request<T, P>> - 1[36] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_reference_property_wrapper_annotation_with_a_generic_optional_type() {
            
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.reference)
                private var request: Request<T, P>?
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "request <- Optional<Request<T, P>> - 64[27] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_comment_annotation() {
        
        let file = File(contents: """

            // weaver: movieID <= UInt
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "movieID <= UInt - 1[26] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_property_wrapper_annotation() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.parameter)
                private var movieID: UInt
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "movieID <= UInt - 64[17] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_comment_annotation_with_an_optional_type() {
        
        let file = File(contents: """

            // weaver: movieID <= UInt?
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "movieID <= Optional<UInt> - 1[27] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_property_wrapper_annotation_with_an_optional_type() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.parameter)
                private var movieID: UInt?
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "movieID <= Optional<UInt> - 64[18] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_comment_annotation_with_a_generaic_type() {
        
        let file = File(contents: """

            // weaver: request <= Request<T, P>
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "request <= Request<T, P> - 1[35] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_property_wrapper_annotation_with_a_generaic_type() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.parameter)
                private var request: Request<T, P>
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "request <= Request<T, P> - 64[26] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_comment_annotation_with_a_generic_optional_type() {
        
        let file = File(contents: """

            // weaver: request <= Request<T, P>?
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "request <= Optional<Request<T, P>> - 1[36] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_parameter_property_wrapper_annotation_with_a_generic_optional_type() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.parameter)
                private var request: Request<T, P>?
            }
            """)
        do {
            let lexer = Lexer(file, fileName: "test.swift")
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "request <= Optional<Request<T, P>> - 64[27] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_custom_builder_comment_annotation() {
        
        let file = File(contents: """

            // weaver: api.builder = make
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "api.Config Attr - builder = make - 1[29] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_custom_builder_property_wrapper_annotation() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.registration, type: Request<T, P>?.self, builder: make)
                private var request: Request<T, P>?
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 4 {
                XCTAssertEqual(tokens[2].description, "request.Config Attr - builder = make - 109[27] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_true_isIsolated_configuration_annotation() {
        
        let file = File(contents: """

            // weaver: self.isIsolated = true
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "self.Config Attr - isIsolated = true - 1[33] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_false_isIsolated_configuration_annotation() {
        
        let file = File(contents: """

            // weaver: self.isIsolated = false
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "self.Config Attr - isIsolated = false - 1[34] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_an_invalid_isIsolated_configuration_annotation() {
        
        let file = File(contents: """

            // weaver: self.isIsolated = ok
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            XCTAssertEqual(error.description, "test.swift:2: error: Invalid configuration attribute value: 'ok'. Expected 'true|false'.")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_generate_an_empty_token_list_with_any_ignored_declaration() {
        
        let file = File(contents: """
            func ignoredFunc() {
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            XCTAssertTrue(tokens.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_an_unknown_configuration_attribute() {
        
        let file = File(contents: """

            // weaver: self.fakeAttribute = true
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            XCTAssertEqual(error.description, "test.swift:2: error: Unknown configuration attribute: 'fakeAttribute'.")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_an_invalid_comment_annotation() {
        
        let file = File(contents: """

            final class MyService {
              let dependencies: DependencyResolver

              // weaver: api = API <-- APIProtocol
              // weaver: api.scope = .container

              init(_ dependencies: DependencyResolver) {
                self.dependencies = dependencies
              }

              func doSomething() {
                otherService.doSomething(in: api).then { result in
                  if let session = self.session {
                    router.redirectSomewhereWeAreLoggedIn()
                  } else {
                    router.redirectSomewhereWeAreLoggedOut()
                  }
                }
              }
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            XCTAssertEqual(error.description, "test.swift:5: error: Invalid token '-' in type '- APIProtocol'.")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_an_invalid_property_wrapper_annotation() {
            
        let file = File(contents: """
            final class MyService {
              let dependencies: DependencyResolver

              @Weaver(.registration, API.self)
              private var api: APIProtocol

              init(_ dependencies: DependencyResolver) {
                self.dependencies = dependencies
              }

              func doSomething() {
                otherService.doSomething(in: api).then { result in
                  if let session = self.session {
                    router.redirectSomewhereWeAreLoggedIn()
                  } else {
                    router.redirectSomewhereWeAreLoggedOut()
                  }
                }
              }
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            XCTAssertEqual(error.description, "error: Invalid annotation: '@Weaver(.registration, API.self)'.")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_throw_an_error_with_the_right_line_and_content_on_a_scope_rule() {
        
        let file = File(contents: """

            final class MyService {
              let dependencies: DependencyResolver

              // weaver: api = API <- APIProtocol
              // weaver: api.scope = .thisScopeDoesNotExists

              init(_ dependencies: DependencyResolver) {
                self.dependencies = dependencies
              }

              func doSomething() {
                otherService.doSomething(in: api).then { result in
                  if let session = self.session {
                    router.redirectSomewhereWeAreLoggedIn()
                  } else {
                    router.redirectSomewhereWeAreLoggedOut()
                  }
                }
              }
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            _ = try lexer.tokenize()
            XCTAssertTrue(false, "Haven't thrown any error.")
        } catch let error as LexerError {
            XCTAssertEqual(error.description, "test.swift:6: error: Invalid configuration attribute value: '.thisScopeDoesNotExists'. Expected 'transient|container|weak|lazy'.")
        } catch {
            XCTAssertTrue(false, "Unexpected error: \(error).")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_weaver_import_declaration() {
        
        let file = File(contents: """

            // weaver: import API
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "import API - 1[21] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_an_import_declaration() {
        
        let file = File(contents: """

            import API
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "import API - 1[10] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_generic_type_declaration() {
        
        let file = File(contents: """

            final class MovieManager {
                // weaver: logger = Logger<String>
            }
            final class Logger<T> {
                // weaver: domain <= T
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 6 {
                XCTAssertEqual(tokens[3].description, "internal Logger<T> { - 75[46] - at line: 4")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_array_type_token_declaration() {
        
        let file = File(contents: """

            final class MovieManager {
                // weaver: array = [String]
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "array = Array<String> - 32[28] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_optional_array_type_token_declaration() {
        
        let file = File(contents: """

            final class MovieManager {
                // weaver: array = [ String? ]?
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "array = Optional<Array<Optional<String>>> - 32[32] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_dict_type_token_declaration() {
        
        let file = File(contents: """

            final class MovieManager {
                // weaver: dict = [ String : Int ]
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "dict = Dictionary<String, Int> - 32[35] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_optional_dict_type_token_declaration() {
        
        let file = File(contents: """

            final class MovieManager {
                // weaver: dict = [String?:Int?]?
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 3 {
                XCTAssertEqual(tokens[1].description, "dict = Optional<Dictionary<Optional<String>, Optional<Int>>> - 32[34] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_platforms_comment_annotation() {
        
        let file = File(contents: """

            // weaver: api.platforms = [.iOS,.watchOS]
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 1 {
                XCTAssertEqual(tokens[0].description, "api.Config Attr - platforms = [.iOS, .watchOS] - 1[42] - at line: 1")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_tokenizer_should_generate_a_valid_token_list_with_a_platforms_property_wrapper_annotation() {
        
        let file = File(contents: """
            final class MovieManager {

                @Weaver(.registration, type: Request<T, P>?.self, platforms: [.iOS, .watchOS])
                private var request: Request<T, P>?
            }
            """)
        let lexer = Lexer(file, fileName: "test.swift")
        
        do {
            let tokens = try lexer.tokenize()
            
            if tokens.count == 4 {
                XCTAssertEqual(tokens[2].description, "request.Config Attr - platforms = [.iOS, .watchOS] - 123[27] - at line: 2")
            } else {
                XCTFail("Unexpected amount of tokens: \(tokens.count).")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
