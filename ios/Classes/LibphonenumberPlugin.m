#import "LibphonenumberPlugin.h"

#import "NBPhoneNumberUtil.h"
#import "NBAsYouTypeFormatter.h"

@interface LibphonenumberPlugin ()
@property(nonatomic, retain) NBPhoneNumberUtil *phoneUtil;
@end

@implementation LibphonenumberPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel methodChannelWithName:@"codeheadlabs.com/libphonenumber"
                                                                binaryMessenger:[registrar messenger]];
    
    LibphonenumberPlugin* instance = [[LibphonenumberPlugin alloc] init];
    instance.phoneUtil = [[NBPhoneNumberUtil alloc] init];
    
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSError *err = nil;
    
    // Call formatAsYouType before parse below because a partial number will not be parsable.
    if ([@"formatAsYouType" isEqualToString:call.method]) {
        NSString *phoneNumber = call.arguments[@"phone_number"];
        NSString *isoCode = call.arguments[@"iso_code"];
        NBAsYouTypeFormatter *f = [[NBAsYouTypeFormatter alloc] initWithRegionCode:isoCode];
        result([f inputString:phoneNumber]);
        return;
    }
    
    if ([@"isValidPhoneNumber" isEqualToString:call.method]) {
        NBPhoneNumber *number = [self validatePhoneNumber:call error:err];
        if (err != nil) {
            result([FlutterError errorWithCode:@"invalid_phone_number" message:@"Invalid Phone Number" details:nil]);
            return;
        }
        NSNumber *validNumber = [NSNumber numberWithBool:[self.phoneUtil isValidNumber:number]];
        result(validNumber);
    } else if ([@"normalizePhoneNumber" isEqualToString:call.method]) {
        NBPhoneNumber *number = [self validatePhoneNumber:call error:err];
        if (err != nil) {
            result([FlutterError errorWithCode:@"invalid_phone_number" message:@"Invalid Phone Number" details:nil]);
            return;
        }
        NSString *normalizedNumber = [self.phoneUtil format:number
                                               numberFormat:NBEPhoneNumberFormatE164
                                                      error:&err];
        if (err != nil) {
            result([FlutterError errorWithCode:@"invalid_national_number"
                                       message:@"Invalid phone number for the country specified"
                                       details:nil]);
            return;
        }
        
        result(normalizedNumber);
    } else if ([@"normalizePhoneNumbers" isEqualToString:call.method]) {
        [self handleNormalizePhoneNumbers:call
                                   result:result];
        return;
    } else if ([@"getRegionInfo" isEqualToString:call.method]) {
        NBPhoneNumber *number = [self validatePhoneNumber:call error:err];
        if (err != nil ) {
            result([FlutterError errorWithCode:@"invalid_national_number"
                                       message:@"Invalid phone number for the country specified"
                                       details:nil]);
            return;
        }
        NSString *regionCode = [self.phoneUtil getRegionCodeForNumber:number];
        NSNumber *countryCode = [self.phoneUtil getCountryCodeForRegion:regionCode];
        NSString *formattedNumber = [self.phoneUtil format:number
                                              numberFormat:NBEPhoneNumberFormatNATIONAL
                                                     error:&err];
        
        
        result(@{
            @"isoCode": regionCode == nil ? @"" : regionCode,
            @"regionCode": countryCode == nil ? @"" : [countryCode stringValue],
            @"formattedPhoneNumber": formattedNumber == nil ? @"" : formattedNumber,
               });
    } else if ([@"getNumberType" isEqualToString:call.method]) {
        NBPhoneNumber *number = [self validatePhoneNumber:call error:err];
        if (err != nil) {
            result([FlutterError errorWithCode:@"invalid_phone_number" message:@"Invalid Phone Number" details:nil]);
            return;
        }
        NSNumber *numberType = [NSNumber numberWithInteger:[self.phoneUtil getNumberType:number]];
        result(numberType);
    } else if([@"getNameForNumber" isEqualToString:call.method]) {
        NSString *name = @"";
        result(name);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

-(NBPhoneNumber *) validatePhoneNumber:(FlutterMethodCall*)call
                                 error:(NSError *)err {
    NSString *phoneNumber = call.arguments[@"phone_number"];
    NSString *isoCode = call.arguments[@"iso_code"];
    
    if (phoneNumber != nil) {
        return [self.phoneUtil parse:phoneNumber
                       defaultRegion:isoCode
                               error:&err];
    }
    return nil;
}

-(void) handleNormalizePhoneNumbers:(FlutterMethodCall*)call
                             result:(FlutterResult)result {
    NSDictionary<NSString*, NSArray<NSString *> *> * phoneNumbers = call.arguments[@"phone_numbers"];
    NSString *isoCode = call.arguments[@"iso_code"];
    NSArray<NSNumber *> *acceptedTypes = call.arguments[@"accepted_types"];
    
    NSMutableDictionary<NSString *, NSArray<NSString *>*> *normalizedResult = @{}.mutableCopy;
    
    for(id contactId in phoneNumbers) {
        NSArray<NSString *> * phones = [phoneNumbers objectForKey:contactId];
        NSMutableArray<NSString *> * normalizedNumbers = @[].mutableCopy;
        for(id phone in phones) {
            NSError * err;
            NBPhoneNumber * phoneNumber = [self.phoneUtil parse:phone
                                                  defaultRegion:isoCode
                                                          error:&err];
            if(err != nil) {
                continue;
            }

            // filter number with acceptedTypes
            NSNumber *numberType = [NSNumber numberWithInteger:[self.phoneUtil getNumberType:phoneNumber]];

            if(err != nil || ([acceptedTypes count] > 0 && ![acceptedTypes containsObject:numberType])) {
                continue;
            }

            NSString *normalizedNumber = [self.phoneUtil format:phoneNumber
                                                   numberFormat:NBEPhoneNumberFormatE164
                                                          error:&err];
            if(err != nil) {
                continue;
            }
            [normalizedNumbers addObject:normalizedNumber];
        }
        [normalizedResult setObject:normalizedNumbers forKey:contactId];
    }
    result(normalizedResult);
}

@end
