//
//  ConditionalOrderedTask.swift
//  ResearchCHIP
//
//  Created by Pascal Pfiffner on 4/27/15.
//  Copyright (c) 2015 Boston Children's Hospital. All rights reserved.
//

import Foundation
import ResearchKit


/**
	An ordered task subclass that can inspect `ConditionalQuestionStep` instances' requirements and skip past questions
	in case the requirements are not met.
 */
class ConditionalOrderedTask: ORKOrderedTask
{
	override func stepAfterStep(step: ORKStep?, withResult result: ORKTaskResult) -> ORKStep? {
		let serialNext = super.stepAfterStep(step, withResult: result)
		
		// does the serial next step have conditional requirements and are they satisfied?
		if let condNext = serialNext as? ConditionalQuestionStep {
			if let ok = condNext.requirementsAreSatisfiedBy(result) where !ok {
				return stepAfterStep(condNext, withResult: result)
			}
		}
		return serialNext
	}
	
	override func stepBeforeStep(step: ORKStep?, withResult result: ORKTaskResult) -> ORKStep? {
		let serialPrev = super.stepBeforeStep(step, withResult: result)
		
		// does the serial previous step have conditional requirements and are they satisfied?
		if let condPrev = serialPrev as? ConditionalQuestionStep {
			if let ok = condPrev.requirementsAreSatisfiedBy(result) where !ok {
				return stepBeforeStep(condPrev, withResult: result)
			}
		}
		return serialPrev
	}
}


class ConditionalQuestionStep: ORKQuestionStep
{
	var requirements: [ResultRequirement]?
	
	
	init(identifier: String, title ttl: String?, answer: ORKAnswerFormat) {
		super.init(identifier: identifier)
		title = ttl
		answerFormat = answer
	}
	
	
	// MARK: - Requirements
	
	func addRequirement(requirement: ResultRequirement) {
		if nil == requirements {
			requirements = [ResultRequirement]()
		}
		requirements!.append(requirement)
	}
	
	func addRequirements(requirements reqs: [ResultRequirement]) {
		if nil == requirements {
			requirements = reqs
		}
		else {
			requirements!.extend(reqs)
		}
	}
	
	/** If the step has requirements, checks if all of them are fulfilled in step results in the given task result.
	
	    :returns: A bool indicating success or failure, nil if there are no requirements
	 */
	func requirementsAreSatisfiedBy(result: ORKTaskResult) -> Bool? {
		if nil == requirements {
			return nil
		}
		
		// check each requirement and drop out early if one fails
		for requirement in requirements! {
			if let stepResult = result.resultForIdentifier(requirement.questionIdentifier as String) as? ORKStepResult {
				if let questionResults = stepResult.results as? [ORKQuestionResult] {
					var ok = false
					for questionResult in questionResults {
						//chip_logIfDebug("===>  \(questionResult.identifier) is \(questionResult.answer), needs to be \(requirement.result.answer): \(questionResult.chip_hasSameAnswer(requirement.result))")
						if questionResult.chip_hasSameAnswer(requirement.result) {
							ok = true
						}
					}
					if !ok {
						return false
					}
				}
				else {
					chip_logIfDebug("Expecting ORKQuestionResult but got \(stepResult.results)")
				}
			}
			else {
				chip_logIfDebug("Next step \(identifier) has a condition on \(requirement.questionIdentifier), but the latter has no result yet")
			}
		}
		return true
	}
	
	
	// MARK: - NSCopying
	
	override func copyWithZone(zone: NSZone) -> AnyObject {
		super.copyWithZone(zone)
		return self
	}
	
	
	// MARK: - NSSecureCoding
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		let set = NSSet(array: [NSArray.self, ResultRequirement.self]) as Set<NSObject>
		requirements = aDecoder.decodeObjectOfClasses(set, forKey: "requirements") as? [ResultRequirement]
	}
	
	override func encodeWithCoder(aCoder: NSCoder) {
		super.encodeWithCoder(aCoder)
		aCoder.encodeObject(requirements, forKey: "requirements")
	}
}


public class ResultRequirement: NSObject, NSCopying, NSSecureCoding
{
	/// The step identifier of the question we have an answer for.
	public var questionIdentifier: NSString
	
	/// The result to match.
	public var result: ORKQuestionResult
	
	
	public init(step: String, result rslt: ORKQuestionResult) {
		questionIdentifier = step as NSString
		result = rslt
	}
	
	
	// MARK: - NSCopying
	
	public func copyWithZone(zone: NSZone) -> AnyObject {
		let copy = self.dynamicType.allocWithZone(zone)
		copy.questionIdentifier = questionIdentifier.copyWithZone(zone) as! NSString
		copy.result = result.copyWithZone(zone) as! ORKQuestionResult
		return copy
	}
	
	
	// MARK: - NSSecureCoding
	
	public class func supportsSecureCoding() -> Bool {
		return true
	}
	
	required public init(coder aDecoder: NSCoder) {
		questionIdentifier = aDecoder.decodeObjectOfClass(NSString.self, forKey: "stepIdentifier") as! NSString
		result = aDecoder.decodeObjectOfClass(ORKQuestionResult.self, forKey: "result") as! ORKQuestionResult
	}
	
	public func encodeWithCoder(aCoder: NSCoder) {
		aCoder.encodeObject(questionIdentifier, forKey: "stepIdentifier")
		aCoder.encodeObject(result, forKey: "result")
	}
}


extension ORKQuestionResult
{
	func chip_hasSameAnswer(other: ORKQuestionResult) -> Bool {
		if let myAnswer: AnyObject = answer {
			if let otherAnswer: AnyObject = other.answer {
				return myAnswer.isEqual(otherAnswer)
			}
		}
		return false
	}
}
