import { describe, expect, it } from "vitest";
import {
  FUNNEL_STEPS,
  funnelStepLabel,
  funnelStepOf,
  inquiryStatusForStep,
  isClosedStep,
  statusForStep,
  stepForInquiryStatus,
  viewingKindFor,
} from "../../src/modules/leads/leadFunnel.js";

describe("funnelStepOf", () => {
  it("reads a step from any pipeline's stage type", () => {
    expect(funnelStepOf("open", "new")).toBe("new");
    expect(funnelStepOf("open", "contacted")).toBe("contacted");
    expect(funnelStepOf("open", "qualified")).toBe("qualified");
    expect(funnelStepOf("open", "nurturing")).toBe("viewing");
    expect(funnelStepOf("open", "proposal")).toBe("negotiating");
    expect(funnelStepOf("open", "negotiation")).toBe("negotiating");
  });

  it("lets the outcome win over a stage left behind", () => {
    expect(funnelStepOf("won", "negotiation")).toBe("won");
    expect(funnelStepOf("lost", "new")).toBe("lost");
    expect(funnelStepOf("disqualified", "qualified")).toBe("lost");
    expect(funnelStepOf("archived", "new")).toBe("lost");
  });

  it("falls back to new rather than inventing a step", () => {
    expect(funnelStepOf("open", null)).toBe("new");
  });
});

describe("what a step means", () => {
  it("is open until the two ends", () => {
    expect(FUNNEL_STEPS.filter(isClosedStep)).toEqual(["won", "lost"]);
    expect(statusForStep("viewing")).toBe("open");
    expect(statusForStep("won")).toBe("won");
    expect(statusForStep("lost")).toBe("lost");
  });

  it("maps every step to an inquiry status and back", () => {
    for (const step of FUNNEL_STEPS) expect(stepForInquiryStatus(inquiryStatusForStep(step))).toBe(step);
  });

  it("leaves tidying an inquiry out of the funnel", () => {
    expect(stepForInquiryStatus("closed")).toBeNull();
    expect(stepForInquiryStatus("spam")).toBeNull();
  });
});

describe("a viewing in each category's words", () => {
  it("is a test drive for a car and a sea trial for a yacht", () => {
    expect(viewingKindFor(2)).toEqual({ label: "Test drive", bookingType: "test_drive" });
    expect(viewingKindFor(3)).toEqual({ label: "Sea trial", bookingType: "sea_trial" });
    expect(viewingKindFor(1)).toEqual({ label: "Viewing", bookingType: "viewing" });
    expect(funnelStepLabel("viewing", 4)).toBe("Inspection");
    expect(funnelStepLabel("won", 4)).toBe("Won");
  });
});
