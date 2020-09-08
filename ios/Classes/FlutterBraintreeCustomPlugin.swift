import Flutter
import UIKit
import Braintree
import BraintreeDropIn

public class FlutterBraintreeCustomPlugin: BaseFlutterBraintreePlugin, FlutterPlugin, BTViewControllerPresentingDelegate, BTThreeDSecureRequestDelegate {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_braintree.custom", binaryMessenger: registrar.messenger())
        
        let instance = FlutterBraintreeCustomPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !isHandlingResult else {
            returnAlreadyOpenError(result: result)
            return
        }
        
        isHandlingResult = true
        
        guard let authorization = getAuthorization(call: call) else {
            returnAuthorizationMissingError(result: result)
            isHandlingResult = false
            return
        }
        
        let client = BTAPIClient(authorization: authorization)
        
        if call.method == "requestPaypalNonce" {
            let driver = BTPayPalDriver(apiClient: client!)
            driver.viewControllerPresentingDelegate = self
            
            guard let requestInfo = dict(for: "request", in: call) else {
                isHandlingResult = false
                return
            }
            
            let amount = requestInfo["amount"] as? String;
            
            if amount == nil {
                driver.authorizeAccount { (nonce, error) in
                    self.handleResult(nonce: nonce, error: error, flutterResult: result)
                    self.isHandlingResult = false
                }
            } else {
                let paypalRequest = BTPayPalRequest(amount: amount!)
                paypalRequest.currencyCode = requestInfo["currencyCode"] as? String;
                paypalRequest.displayName = requestInfo["displayName"] as? String;
                paypalRequest.billingAgreementDescription = requestInfo["billingAgreementDescription"] as? String;
                
                driver.requestOneTimePayment(paypalRequest) { (nonce, error) in
                    self.handleResult(nonce: nonce, error: error, flutterResult: result)
                    self.isHandlingResult = false
                }
            }
            
        } else if call.method == "tokenizeCreditCard" {
            let cardClient = BTCardClient(apiClient: client!)
            
            guard let cardRequestInfo = dict(for: "request", in: call) else {return}
            
            let card = BTCard(number: (cardRequestInfo["cardNumber"] as? String)!,
                              expirationMonth: (cardRequestInfo["expirationMonth"] as? String)!,
                              expirationYear: (cardRequestInfo["expirationYear"] as? String)!,
                              cvv: (cardRequestInfo["cvv"] as? String))
            
            cardClient.tokenizeCard(card) { (nonce, error) in
                self.handleResult(nonce: nonce, error: error, flutterResult: result)
                self.isHandlingResult = false
            }
        } else if call.method == "threeDSecure" {
            let paymentFlowDriver = BTPaymentFlowDriver(apiClient: client!)
            paymentFlowDriver.viewControllerPresentingDelegate = self
            
            guard let requestInfo = dict(for: "request", in: call) else {
                isHandlingResult = false
                return
            }
            
            let threeDSecureRequest = BTThreeDSecureRequest()
            
            if let amount = requestInfo["amount"] as? String {
                threeDSecureRequest.amount = NSDecimalNumber(string: amount)
            }
            
            if let nonce = requestInfo["nonce"] as? String {
                threeDSecureRequest.nonce = nonce
            }
            
            threeDSecureRequest.versionRequested = .version2
            
            threeDSecureRequest.threeDSecureRequestDelegate = self
            
            paymentFlowDriver.startPaymentFlow(threeDSecureRequest) { (btResult, error) in
                self.handleResult(nonce: (btResult as? BTThreeDSecureResult)?.tokenizedCard,
                                  error: error,
                                  flutterResult: result)
                self.isHandlingResult = false
                
//                if (nonce.threeDSecureInfo.liabilityShiftPossible) {
//                    if (nonce.threeDSecureInfo.liabilityShifted) {
//                        // 3D Secure authentication success
//                    } else {
//                        // 3D Secure authentication failed
//                    }
//                } else {
//                    // 3D Secure authentication was not possible
//                }
            }
            
        } else {
            result(FlutterMethodNotImplemented)
            self.isHandlingResult = false
        }
    }
    
    private func handleResult(nonce: BTPaymentMethodNonce?, error: Error?, flutterResult: FlutterResult) {
        if error != nil {
            returnBraintreeError(result: flutterResult, error: error!)
        } else if nonce == nil {
            flutterResult(nil)
        } else {
            flutterResult(buildPaymentNonceDict(nonce: nonce));
        }
    }
    
    public func paymentDriver(_ driver: Any, requestsPresentationOf viewController: UIViewController) {
        UIApplication.shared.keyWindow?.rootViewController?.present(viewController, animated: true)
    }
    
    // Este método es el que no se está llamando
    public func paymentDriver(_ driver: Any, requestsDismissalOf viewController: UIViewController) {
        print("requestsDismissalOf viewController")
        //viewController.dismiss(animated: true, completion: nil)
        UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
    }
    
    public func onLookupComplete(_ request: BTThreeDSecureRequest, result: BTThreeDSecureLookup, next: @escaping () -> Void) {
        next()
    }
}
