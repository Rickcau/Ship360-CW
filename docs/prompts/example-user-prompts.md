# Example User Prompts - 5/21/2024
These user prompts were provided by the user on 5/21/2025.

I also add some notes and thoughts on the steps needed in order to ensure we can properly respond to these prompts.

## Prompts

### Without Order
"Find the most cost-effective shipping option for a 2 oz package measuring 10x6x4 inches from ZIP 10001 to 94105." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)
Better to test with: Find the most cost-effective shipping option for a 2 oz package measuring 10x6x4 inches from 421 8th Avenue, New York, NY 10001, US to 415 Mission Street, San Francisco, CA 94105, US

"Rate shop carriers for this package (10x6x4 in, 2 lbs) from New York to San Francisco and pick the best value." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)
Better to test with: Rate shop carriers for this package (10x6x4 in, 2 oz) from 421 8th Avenue, New York, NY 10001, US to 415 Mission Street, San Francisco, CA 94105 and pick the best value.

"Compare shipping options for this box (10x6x4, 2 pounds) from 10001 to 94105 and generate the cheapest label with delivery in 3 days." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)
Better to test with: Compare shipping options for this box (10x6x4, 2 oz) from 421 8th Avenue, New York, NY 10001, US to 415 Mission Street, San Francisco, CA 94105 and generate the cheapest label with delivery in 3 days.

"What’s the best shipping method for a 2-pound box from ZIP 10001 to 94105 with a 3-day delivery limit?" "Compare FedEx, UPS, and USPS for a shipment from Atlanta to Seattle and use the cheapest one with tracking." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed) (API requires dim, so need logic to deal with this)
Better to test with: What’s the best shipping method for a 2 oz box from 421 8th Avenue, New York, NY 10001, US to 415 Mission Street, San Francisco, CA 94105 with a 3-day delivery limit?
You will then follow up with: The package is 10x6x4 inches.

"Compare FedEx, UPS, and USPS for a shipment from 27 Waterview Dr, Danbury, CT 06811 US to 802 Rail Fence Rd, Orange, CT 06477 US and use the cheapest one with tracking."

"Look up rates from FedEx, USPS, and UPS for shipping from Atlanta to Seattle - select the lowest with tracking." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed) (API requires dim, so need logic to deal with this)
Better to test with: Look up rates from FedEx, USPS, and UPS for shipping from 27 Waterview Dr, Danbury, CT 06811 US to 802 Rail Fence Rd, Orange, CT 06477 US - select the lowest with tracking.
Follow up with: The package is 10x6x4 inches weighing 6 oz.

"Find the best tracked option between USPS, UPS, and FedEx for this Atlanta to Seattle shipment and create the label." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed) (API requires dim, so need logic to deal with this)
Better to test with: Find the best tracked option between USPS, UPS, and FedEx for this 27 Waterview Dr, Danbury, CT 06811 US to 802 Rail Fence Rd, Orange, CT 06477 US shipment and create the label.
Follow up with: The package is 10x6x4 inches weighing 6 ox.

### With Order Number
"Generate a shipping label for Order #1005101 with the fastest delivery option under $15." ( was working, but need more testing) need to make sure all information is avail, otherwise ask for more info. This should 1) rate shop based on information from order and return the carrier id for the fastest delivery under $15. 2) Call create shipping label with this carrier id.

"What’s the quickest shipping method under $15 for order #1005101? Print the label." Steps: Confusing question for LLM, need to make sure it asks for more details. This should ask for the paper size, otherwise, it should choose the best option and then create the label.

"Label this order #1005101 with a carrier offering fast delivery and keeping cost below $15." (carrier offering, LLM may not know these terms, so LLM needs to ask for more info until it understands. As expected, LLM will list the shipping options which are < $15 and end the response by asking: "Would you like to select one of these shipping options to create a shipping label? If so, please specify the option number.", which seems correct.

"Pick a shipping option under $15 with the soonest delivery date and generate a label for this order." so again clarifying questions need to be asked when it's not clear what to do.



