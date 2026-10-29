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
    expect(result.items.map((item) => item.errors)).toEqual([null, null]);
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
    expect(item.errors).toBeNull();
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
