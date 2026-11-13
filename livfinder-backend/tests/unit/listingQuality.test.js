import { describe, expect, it } from "vitest";
import { qualityBand, scoreListing } from "../../src/modules/quality/listingQuality.js";
import { agentProfileChecks, organizationProfileChecks } from "../../src/modules/quality/profileQuality.js";

const longText = "A bright, well kept home with open views and a quiet street outside. ".repeat(12);

/** A real-estate listing with everything the rubric asks for. */
function complete(over = {}) {
  return {
    category: "real-estate",
    purpose: "sale",
    title: "Three bedroom villa with private pool in Arabian Ranches",
    descriptionText: longText,
    price: 4500000,
    priceOnRequest: false,
    segment: "residential",
    isLand: false,
    detail: {
      bedrooms: 3, bathrooms: 4, halfBathrooms: 1, receptionRooms: 1, maidRooms: 1, parkingSpaces: 2,
      builtAreaSqft: 3200, completionStatus: "ready", furnishing: "unfurnished", viewType: "Garden",
      ownershipType: "freehold", yearBuilt: 2015,
    },
    imageCount: 12,
    videoCount: 0,
    hasFloorPlan: true,
    hasVirtualTour: false,
    featureCount: 8,
    location: { cityId: 3, communityId: 4, countryHasCities: true, cityHasCommunities: true, hasPin: true },
    permit: { required: false, has: false },
    photoReview: null,
    ...over,
  };
}

describe("listing quality score", () => {
  it("gives a complete listing 100 and no suggestions", () => {
    const result = scoreListing(complete());
    expect(result.score).toBe(100);
    expect(result.band.id).toBe("good");
    expect(result.suggestions).toEqual([]);
    // No permit is required here, so that part is left out rather than scored 0.
    expect(result.parts.map((part) => part.key)).not.toContain("permit");
  });

  it("scores photos 25 at 10+, 15 at 5, 3 each below 5", () => {
    const photos = (n) => scoreListing(complete({ imageCount: n })).parts.find((part) => part.key === "photos").earned;
    expect(photos(10)).toBe(25);
    expect(photos(9)).toBe(23);
    expect(photos(5)).toBe(15);
    expect(photos(3)).toBe(9);
    expect(photos(0)).toBe(0);
  });

  it("asks for the permit only where the country requires one", () => {
    const missing = scoreListing(complete({ permit: { required: true, has: false, label: "DLD permit" } }));
    expect(missing.score).toBeLessThan(100);
    expect(missing.suggestions[0]).toMatchObject({ id: "permit.missing", step: { id: "specifications" } });
    expect(missing.suggestions[0].message).toMatch(/DLD permit/);
    expect(scoreListing(complete({ permit: { required: true, has: true } })).score).toBe(100);
  });

  it("leaves rooms out for land and bedrooms out for commercial", () => {
    const land = complete({ isLand: true, detail: { plotAreaSqft: 9000, completionStatus: "ready", viewType: "Sea", ownershipType: "freehold" } });
    expect(scoreListing(land).score).toBe(100);
    const office = complete({ segment: "commercial", detail: { ...complete().detail, bedrooms: null, receptionRooms: null, maidRooms: null } });
    expect(scoreListing(office).score).toBe(100);
  });

  it("names the missing key details and points to the form step", () => {
    const result = scoreListing(complete({ detail: { ...complete().detail, bedrooms: null, furnishing: null } }));
    const issue = result.suggestions.find((item) => item.id === "required.missing");
    expect(issue.fields).toEqual(["bedrooms", "furnishing"]);
    expect(issue.message).toBe("Missing: Bedrooms, Furnishing.");
    expect(issue.step.id).toBe("specifications");
  });

  it("counts price on request as a price", () => {
    expect(scoreListing(complete({ price: null, priceOnRequest: true })).score).toBe(100);
  });

  it("marks down an all-capitals title", () => {
    const result = scoreListing(complete({ title: "STUNNING VILLA WITH POOL AND GARDEN VIEWS FOR SALE" }));
    expect(result.parts.find((part) => part.key === "title").earned).toBe(3);
    expect(result.suggestions.map((item) => item.id)).toContain("title.caps");
  });

  it("orders suggestions by the points they would add", () => {
    const result = scoreListing(complete({ imageCount: 2, featureCount: 4, location: { ...complete().location, hasPin: false } }));
    const gains = result.suggestions.map((item) => item.gain);
    expect(gains).toEqual([...gains].sort((a, b) => b - a));
    expect(result.suggestions[0].id).toBe("photos.count");
  });

  it("adds a photo-quality part only once an AI review exists", () => {
    expect(scoreListing(complete()).parts.map((part) => part.key)).not.toContain("photoQuality");
    const reviewed = scoreListing(complete({ photoReview: { score: 50, notes: [{ message: "Two photos are dark.", suggestion: "Retake them in daylight." }] } }));
    expect(reviewed.parts.find((part) => part.key === "photoQuality")).toMatchObject({ earned: 5, max: 10 });
    expect(reviewed.score).toBe(95);
    expect(reviewed.photoCheck).toBe("reviewed");
  });

  it("uses red under 50, yellow under 80, green from 80", () => {
    expect(qualityBand(0).tone).toBe("red");
    expect(qualityBand(49).tone).toBe("red");
    expect(qualityBand(50).tone).toBe("yellow");
    expect(qualityBand(79).tone).toBe("yellow");
    expect(qualityBand(80).tone).toBe("green");
    expect(qualityBand(100).tone).toBe("green");
  });

  it("scores a car on its own fields", () => {
    const car = {
      category: "cars", purpose: "sale", title: "Porsche 911 Carrera S with sport chrono and low mileage", descriptionText: longText,
      price: 500000, brandId: 1, modelId: 2,
      detail: {
        modelYear: 2022, mileageKm: 8000, bodyType: "coupe", transmission: "automatic", fuelType: "petrol", exteriorColor: "Black",
        conditionType: "used", regionalSpec: "gcc", drivetrain: "rwd", horsepower: 450, torqueNm: 530, topSpeedKmh: 308,
        interiorColor: "Red", doors: 2, seats: 4, steeringSide: "left", ownersCount: 1, engineSizeCc: 2981, cylinders: 6,
      },
      imageCount: 15, videoCount: 1, featureCount: 6,
      location: { cityId: 1, communityId: null, countryHasCities: true, cityHasCommunities: false, hasPin: true },
      permit: { required: false },
    };
    expect(scoreListing(car).score).toBe(100);
    // An electric car has no engine size or cylinders to give.
    const electric = { ...car, detail: { ...car.detail, fuelType: "electric", engineSizeCc: null, cylinders: null } };
    expect(scoreListing(electric).score).toBe(100);
  });
});

describe("agent and company profile checks", () => {
  it("add up to 100 points each", () => {
    expect(agentProfileChecks({}).reduce((sum, check) => sum + check.points, 0)).toBe(100);
    expect(organizationProfileChecks({}).reduce((sum, check) => sum + check.points, 0)).toBe(100);
  });

  it("tick Verified agent only for a verified agent", () => {
    const verified = agentProfileChecks({ verification_status: "verified" }).find((check) => check.key === "verified");
    const pending = agentProfileChecks({ verification_status: "pending" }).find((check) => check.key === "verified");
    expect(verified.done).toBe(true);
    expect(pending.done).toBe(false);
  });
});
