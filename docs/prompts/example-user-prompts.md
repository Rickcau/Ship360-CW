# Example User Prompts - 5/21/2024
These user prompts were provided by the user on 5/21/2025.

I also add some notes and thoughts on the steps needed in order to ensure we can properly respond to these prompts.

## Prompts

### Without Order
Find the most cost-effective shipping option for a 2 lb package measuring 10x6x4 inches from ZIP 10001 to 94105." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)

**Update 5/21**: RDC system prompt is working as expect, once all details are provided, the SK function perform_rate_shop_without_order_id is called.  More work needs to be done to finish the logic, but basic flow for this prompt is working!

#### Logic for this Prompt
1. In order to get rates to ship to any destination we need the following details:
- Package weight: weight units (e.g., pounds, kg), weight
- Package dimensions: length, width, height dimension units (e.g., inches, cm)
- Shipping origin: Address, city, state, and zip code
- Shipping destination: Address, city, state, and zip code
- Country Code: 2-letter country code (e.g., US, CA) give the user examples if needed
2. The logic (system prompt) should detect these details are present and ask for them before doing anything.
3. When the system asks for more details, you can use the following details to finish the interaction:
   ```
      Address: 421 8th Avenue, New York, NY 10001
      Note: This is the James A. Farley Building, formerly the main United States Postal Service building in NYC, now redeveloped as part of the Moynihan 
      Train Hall.
   ```

   ```
      Address: 415 Mission Street, San Francisco, CA 94105
      Note: This is the Salesforce Tower, one of the most well-known skyscrapers in San Francisco.
   ```

"Rate shop carriers for this package (10x6x4 in, 2 lbs) from New York to San Francisco and pick the best value." Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)

**Update 5/21**: RDC system prompt is working as expect, once all details are provided, the SK function perform_rate_shop_without_order_id is called.  More work needs to be done to finish the logic, but basic flow for this prompt is working!

#### Logic for this Prompt
Same logic as above and since this is using New York and San Francisco, the same address info in the above example can be used.

"Compare shipping options for this box (10x6x4, 2 pounds) from 10001 to 94105 and generate the cheapest label with delivery in 3 days."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)

**Update 5/21**: RDC system prompt is working as expect, once all details are provided, the SK function perform_rate_shop_without_order_id is called.  More work needs to be done to finish the logic, but basic flow for this prompt is working!  We also need to add the filtering logic that Chris added.

#### Logic for this Prompt
1. In order to get rates to ship to any destination we need the following details:
- Package weight: weight units (e.g., pounds, kg), weight
- Package dimensions: length, width, height dimension units (e.g., inches, cm)
- Shipping origin: Address, city, state, and zip code
- Shipping destination: Address, city, state, and zip code
- Country Code: 2-letter country code (e.g., US, CA) give the user examples if needed
2. The logic (system prompt) should detect these details are present and ask for them before doing anything.
3. When the system asks for more details, you can use the same address info in the above examples.
4. When the rates are returned we will need to use the same filtering logic that Chris implemented for the Rate Shop using Order ID.

"What’s the best shipping method for a 2-pound box from ZIP 10001 to 94105 with a 3-day delivery limit?" 

**Update 5/21**: RDC system prompt is working as expect, once all details are provided, the SK function perform_rate_shop_without_order_id is called.  More work needs to be done to finish the logic, but basic flow for this prompt is working!  We also need to add the filtering logic that Chris added.

#### Logic for this prompt
Same logic as the other prompts is needed., but logic needs to be add that allows filter by 3-day limits.

"Compare FedEx, UPS, and USPS for a shipment from Atlanta to Seattle and use the cheapest one with tracking."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)  (API requires dim, so need logic to deal with this)

"Look up rates from FedEx, USPS, and UPS for shipping from Atlanta to Seattle - select the lowest with tracking."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)  (API requires dim, so need logic to deal with this)

"Find the best tracked option between USPS, UPS, and FedEx for this Atlanta to Seattle shipment and create the label."  Steps: (param extract: RateShop Call, provide response to user, additional prompt engineering needed)  (API requires dim, so need logic to deal with this)

### With Order Number
"Generate a shipping label for Order **#2433232** with the fastest delivery option under $15."
( was working, but need more testing)  need to make sure all information is avail, otherwise ask for more info.

"What’s the quickest shipping method under $15 for order **#2433232**? Print the label."
Steps:  Confusing question for LLM, ned to make sure it asks for more details.

"Label this order **#2433232** with a carrier offering fast delivery and keeping cost below $15."
(carrier offering, LLM may not know these terms, so LLM needs to ask for more info until it understands.

"Pick a shipping option under $15 with the soonest delivery date and generate a label for this order."
so again clarifying questions need to be asked when it's not clear what to do.  



