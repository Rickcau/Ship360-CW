# Example User Prompts - 5/21/2024
These user prompts were provided by the user on 5/21/2025.

I also add some notes and thoughts on the steps needed in order to ensure we can properly respond to these prompts.

## Prompts

Find the most cost-effective shipping option for a 2 lb package measuring 10x6x4 inches from ZIP 10001 to 94105." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)

"Rate shop carriers for this package (10x6x4 in, 2 lbs) from New York to San Francisco and pick the best value." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)

"Compare shipping options for this box (10x6x4, 2 pounds) from 10001 to 94105 and generate the cheapest label with delivery in 3 days."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)

"What’s the best shipping method for a 2-pound box from ZIP 10001 to 94105 with a 3-day delivery limit?" 
"Compare FedEx, UPS, and USPS for a shipment from Atlanta to Seattle and use the cheapest one with tracking."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)  (API requires dim, so need logic to deal with this)

"Look up rates from FedEx, USPS, and UPS for shipping from Atlanta to Seattle - select the lowest with tracking."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)  (API requires dim, so need logic to deal with this)

"Find the best tracked option between USPS, UPS, and FedEx for this Atlanta to Seattle shipment and create the label."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)  (API requires dim, so need logic to deal with this)

"Generate a shipping label for Order #2433232 with the fastest delivery option under $15."
( was working, but need more testing)  need to make sure all information is avail, otherwise ask for more info.

"What’s the quickest shipping method under $15 for order #2433232? Print the label."
Steps:  Confusing question for LLM, ned to make sure it asks for more details.

"Label this order #2433232 with a carrier offering fast delivery and keeping cost below $15."
(carrier offering, LLM may not know these terms, so LLM needs to ask for more info until it understands.

"Pick a shipping option under $15 with the soonest delivery date and generate a label for this order."
so again clarifying questions need to be asked when it's not clear what to do.  



