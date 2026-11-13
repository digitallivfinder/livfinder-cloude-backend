import { describe, expect, it } from "vitest";
import { parseFeed } from "../../src/modules/feeds/feedParser.js";
import { readForeignXml } from "../../src/modules/feeds/foreignFormats.js";

/**
 * Property Finder and Bayut exports read into LivFinder's real-estate fields (Phase 5). The
 * samples use the field names those portals' feeds are known to carry; a real client file is the
 * final check.
 */

const PROPERTY_FINDER = `<?xml version="1.0" encoding="UTF-8"?>
<list last_update="2026-10-29 10:00:00" listing_count="2">
  <property last_update="2026-10-28 09:00:00">
    <reference_number>PF-1001</reference_number>
    <permit_number>7112345678</permit_number>
    <offering_type>RS</offering_type>
    <property_type>AP</property_type>
    <price>2500000</price>
    <city>Dubai</city>
    <community>Dubai Marina</community>
    <sub_community>Marina Gate</sub_community>
    <property_name>Marina Gate 1</property_name>
    <title_en>2 bedroom apartment with marina view</title_en>
    <description_en><![CDATA[Bright <b>two bedroom</b> apartment.]]></description_en>
    <private_amenities>BA,BP,SP</private_amenities>
    <size>1350</size>
    <bedroom>2</bedroom>
    <bathroom>3</bathroom>
    <furnished>Partly</furnished>
    <completion_status>completed</completion_status>
    <geopoints>25.0806,55.1403</geopoints>
    <agent><id>12</id><name>Sara Agent</name><email>sara@example.com</email></agent>
    <photo>
      <url last_update="2026-10-01" watermark="Yes">https://images.example.com/pf/1.jpg</url>
      <url last_update="2026-10-01" watermark="Yes">https://images.example.com/pf/2.jpg</url>
    </photo>
  </property>
  <property>
    <reference_number>PF-1002</reference_number>
    <offering_type>RR</offering_type>
    <property_type>VH</property_type>
    <price><yearly>480000</yearly><monthly>42000</monthly></price>
    <city>Dubai</city>
    <community>Arabian Ranches</community>
    <title_en>Studio villa for rent</title_en>
    <bedroom>studio</bedroom>
  </property>
</list>`;

const BAYUT = `<?xml version="1.0" encoding="UTF-8"?>
<Listings>
  <Listing>
    <Property_Ref_No>BY-77</Property_Ref_No>
    <Permit_Number>7119998888</Permit_Number>
    <Property_purpose>Rent</Property_purpose>
    <Property_Type>Townhouse</Property_Type>
    <City>Dubai</City>
    <Locality>Dubai Hills Estate</Locality>
    <Property_Title>3 bedroom townhouse in Dubai Hills</Property_Title>
    <Property_Description>Close to the park.</Property_Description>
    <Property_Size>2400</Property_Size>
    <Property_Size_Unit>SQFT</Property_Size_Unit>
    <Bedrooms>3</Bedrooms>
    <Bathroom>4</Bathroom>
    <Price>320000</Price>
    <Rent_Frequency>Yearly</Rent_Frequency>
    <Off_plan>No</Off_plan>
    <Furnished>No</Furnished>
    <Listing_Agent_Email>omar@example.com</Listing_Agent_Email>
    <Features><Feature>Maids Room</Feature><Feature>Private Garden</Feature></Features>
    <Images><Image>https://images.example.com/by/1.jpg</Image></Images>
  </Listing>
</Listings>`;

describe("Property Finder", () => {
  it("is recognised and read into LivFinder's real-estate fields", () => {
    const result = parseFeed({ category: "real-estate", format: "xml", content: PROPERTY_FINDER });
    expect(result.source).toBe("property_finder");
    const [sale, rent] = result.items.map((item) => item.record);
    expect(sale).toMatchObject({
      externalId: "PF-1001",
      category: "real-estate",
      purpose: "sale",
      propertyType: "apartment",
      title: "2 bedroom apartment with marina view",
      price: 2500000,
      currency: "AED",
      location: { country: "AE", city: "Dubai", community: "Dubai Marina", subCommunity: "Marina Gate" },
      latitude: 25.0806,
      longitude: 55.1403,
      agentEmail: "sara@example.com",
      images: ["https://images.example.com/pf/1.jpg", "https://images.example.com/pf/2.jpg"],
      features: ["BA", "BP", "SP"],
      detail: {
        bedrooms: 2,
        bathrooms: 3,
        builtAreaSqft: 1350,
        buildingName: "Marina Gate 1",
        permitNumber: "7112345678",
        furnishing: "semi_furnished",
        completionStatus: "ready",
      },
    });
    expect(sale.description).toContain("two bedroom");
    expect(rent).toMatchObject({ externalId: "PF-1002", purpose: "rent", propertyType: "villa", price: 480000, pricePeriod: "year", detail: { bedrooms: 0 } });
  });
});

describe("Bayut", () => {
  it("is recognised and read into LivFinder's real-estate fields", () => {
    const result = parseFeed({ category: "real-estate", format: "xml", content: BAYUT });
    expect(result.source).toBe("bayut");
    const [item] = result.items;
    expect(item.record).toMatchObject({
      externalId: "BY-77",
      purpose: "rent",
      propertyType: "Townhouse",
      price: 320000,
      pricePeriod: "year",
      location: { country: "AE", city: "Dubai", community: "Dubai Hills Estate" },
      agentEmail: "omar@example.com",
      features: ["Maids Room", "Private Garden"],
      images: ["https://images.example.com/by/1.jpg"],
      detail: { bedrooms: 3, bathrooms: 4, builtAreaSqft: 2400, permitNumber: "7119998888", furnishing: "unfurnished", completionStatus: "ready" },
    });
  });
});

describe("telling formats apart", () => {
  it("reads portal files only for real estate, and refuses anything else it does not know", () => {
    expect(() => parseFeed({ category: "cars", format: "xml", content: PROPERTY_FINDER })).toThrow(/livfinder-feed/);
    expect(() => parseFeed({ category: "real-estate", format: "xml", content: "<catalog><item/></catalog>" })).toThrow(/Property Finder or Bayut/);
    expect(readForeignXml("<catalog><item/></catalog>")).toBeNull();
  });

  it("reports a portal entry it cannot use, with the field", () => {
    const missingTitle = PROPERTY_FINDER.replace("<title_en>2 bedroom apartment with marina view</title_en>", "");
    const [first] = parseFeed({ category: "real-estate", format: "xml", content: missingTitle }).items;
    expect(first.errors).toMatchObject({ title: "This is required." });
  });
});

describe("an export that lacks LivFinder's required fields", () => {
  it("is read, and each listing says what it is missing", () => {
    const [entry] = parseFeed({ category: "real-estate", format: "xml", content: PROPERTY_FINDER }).items;
    expect(entry.errors.images).toMatch(/at least 3/);
    expect(entry.errors.parkingSpaces).toBe("This is required.");
  });
});

// The variant LuxuryProperty.com exports (2026-11-13): spelled-out types and offering, a
// <category> for Residential / Commercial, and the place in location_lv1 … location_lv5.
const LEVELLED = `<?xml version="1.0" encoding="UTF-8"?>
<list last_update="2024-07-15 04:25:35" listing_count="2">
  <property last_update="2025-11-24 10:30:16">
    <reference_number>LP0001</reference_number><offering_type>Purchase</offering_type><property_type>Apartment</property_type>
    <price_on_application>No</price_on_application><price>1131296</price><currency_code>AED</currency_code>
    <title_en>One bedroom in District One</title_en><description_en>&lt;p&gt;Calm and bright.&lt;/p&gt;</description_en>
    <size>761</size><size_measure>Square Foot</size_measure><bedroom>1</bedroom><bathroom>1</bathroom>
    <agent><id>34</id><name>Jason Hayes</name><email>jason@luxuryproperty.com</email><photo><url>https://example.com/a.webp</url></photo></agent>
    <listing_status>Y</listing_status><furnished>Unfurnished</furnished><category>Residential</category>
    <location_lv1>UAE</location_lv1><location_lv2>Dubai</location_lv2><location_lv3>Mohammed Bin Rashid City</location_lv3>
    <location_lv4>District One</location_lv4><location_lv5>The Residences</location_lv5>
    <completion_status>off_plan_primary</completion_status><parking>1</parking>
  </property>
  <property>
    <reference_number>LP0002</reference_number><offering_type>Rental</offering_type><property_type>Office</property_type>
    <price><yearly>0</yearly></price><currency_code>AED</currency_code><title_en>Office</title_en><description_en>Desk space.</description_en>
    <size>120</size><size_measure>Square Meter</size_measure><category>Commercial</category><cheques>4</cheques>
    <availability_date>2024-10-10 00:00:00</availability_date>
    <location_lv1>UAE</location_lv1><location_lv2>Dubai</location_lv2><location_lv3>Business Bay</location_lv3>
  </property>
</list>`;

describe("Property Finder with location levels", () => {
  it("reads location_lv1 … lv5, spelled-out types, <category> and a 0 price as no price", () => {
    const { source, entries } = readForeignXml(LEVELLED);
    expect(source).toBe("property_finder");
    const [sale, rent] = entries;
    expect(sale).toMatchObject({
      externalId: "LP0001",
      purpose: "sale",
      propertyType: "Apartment",
      propertySegment: "residential",
      price: "1131296",
      currency: "AED",
      country: "AE",
      city: "Dubai",
      community: "Mohammed Bin Rashid City",
      subCommunity: "District One",
      buildingName: "The Residences",
      builtAreaSqft: "761",
      completionStatus: "off_plan",
      agentEmail: "jason@luxuryproperty.com",
    });
    // The agent's own photo is not a listing image.
    expect(sale.images).toBeUndefined();
    expect(rent).toMatchObject({ purpose: "rent", propertySegment: "commercial", rentPeriod: "yearly", chequesAccepted: "4", availableFrom: "2024-10-10", builtAreaSqm: "120" });
    expect(rent.price).toBeUndefined();
  });

  it("asks for a price when the export gives 0", () => {
    const [, rent] = parseFeed({ category: "real-estate", format: "xml", content: LEVELLED }).items;
    expect(rent.errors.price).toMatch(/Give a price/);
  });
});
