//
//  QuestionnaireExtensions.swift
//  C3PRO
//
//  Created by Pascal Pfiffner on 5/20/15.
//  Copyright © 2015 Boston Children's Hospital. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import SMART
import ResearchKit


/** Extending `SMART.QuestionnaireItem` for use with ResearchKit. */
extension Element {
	
	/**
	Tries to find the "enableWhen" extension on questionnaire groups and questions, and if there are any instantiates ResultRequirements
	representing those.
	*/
	func c3_enableQuestionnaireElementWhen() throws -> [ResultRequirement]? {
		if let enableWhen = extensions(forURI: "http://hl7.org/fhir/StructureDefinition/questionnaire-enableWhen") {
			var requirements = [ResultRequirement]()
			
			for when in enableWhen {
				let question = when.extension_fhir?.filter() { return $0.url?.fragment == "question" }.first
				let answer = when.extension_fhir?.filter() { return $0.url?.fragment == "answer" }.first
				if let answer = answer, let questionIdentifier = question?.valueString {
					let result = try answer.c3_desiredResultForValueOfStep(stepIdentifier: questionIdentifier)
					let req = ResultRequirement(step: questionIdentifier, result: result)
					requirements.append(req)
				}
				else if nil != answer {
					throw C3Error.extensionIncomplete("'enableWhen' extension on \(self) has no #question.valueString as identifier")
				}
				else {
					throw C3Error.extensionIncomplete("'enableWhen' extension on \(self) has no #answer")
				}
			}
			return requirements
		}
		return nil
	}
}


/** Extending `SMART.QuestionnaireItemEnableWhen` for use with ResearchKit. */
extension Extension {
	
	/**
	Returns the result that is required for the parent element to be shown.
	
	Throws if the receiver cannot be converted to a result, you might want to be graceful catching these errors. Currently supports:
	
	- answerBoolean
	- answerCoding
	
	- parameter questionIdentifier: The identifier of the question step this extension applies to
	- returns: An `ORKQuestionResult` representing the result that is required for the item to be shown
	*/
	func c3_desiredResultForValueOfStep(stepIdentifier: String) throws -> ORKQuestionResult {
		if "answer" != url?.fragment {
			throw C3Error.extensionInvalidInContext
		}
		
		// standard bool switch
		if let flag = valueBoolean {
			let result = ORKBooleanQuestionResult(identifier: stepIdentifier)
			result.answer = flag
			return result
		}
		
		// "Coding" value, which should be represented as a choice question
		if let val = valueCoding {
			if let code = val.code {
				let result = ORKChoiceQuestionResult(identifier: stepIdentifier)
				let system = val.system?.absoluteString ?? kORKTextChoiceDefaultSystem
				let value = "\(system)\(kORKTextChoiceSystemSeparator)\(code)"
				result.answer = [value]
				return result
			}
			throw C3Error.extensionIncomplete("Extension has `valueCoding` but is missing a code, cannot create an answer")
		}
		throw C3Error.notImplemented("create question results from value types other than bool and codeable concept, skipping \(url)")
	}
}
