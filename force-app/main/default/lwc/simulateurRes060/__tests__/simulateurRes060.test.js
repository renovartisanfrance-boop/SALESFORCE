import { createElement } from "lwc";
import SimulateurRes060 from "c/simulateurRes060";
import simuler from "@salesforce/apex/SimulationRES060Controller.simuler";
import { createRecord } from "lightning/uiRecordApi";

jest.mock(
  "@salesforce/apex/SimulationRES060Controller.simuler",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const RESULTAT_ROUGE = {
  Province__c: "Madrid",
  Prix_Valorisation__c: 160,
  DCAL__c: 212.8,
  Rendement__c: 0.7,
  AES_MWh__c: 31.65,
  Prime__c: 9622.12,
  Cout_Pack__c: 6600,
  Benefice__c: 3022.12,
  Indice__c: 3.0,
  Zone__c: "Zone rouge · à traiter en janvier",
  Statut__c: "Éligible"
};
const RESULTAT_VERT = {
  ...RESULTAT_ROUGE,
  Indice__c: 14.8,
  Zone__c: "Zone verte · prioritaire",
  Statut__c: "Éligible · cascade 2 PAC"
};

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function monter() {
  const el = createElement("c-simulateur-res060", { is: SimulateurRes060 });
  document.body.appendChild(el);
  return el;
}

describe("c-simulateur-res060", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("affiche l'indice et la zone rouge après le calcul", async () => {
    simuler.mockResolvedValue(RESULTAT_ROUGE);
    const el = monter();
    await flush();

    expect(simuler).toHaveBeenCalledTimes(1);
    expect(simuler.mock.calls[0][0].simulation.Type_Chaudiere__c).toBe("Gaz");
    const indice = el.shadowRoot.querySelector('[data-id="indice"]');
    expect(indice.textContent).toBe("3,0");
    const barre = el.shadowRoot.querySelector('[data-id="barre"]');
    expect(barre.className).toContain("z-red");
    expect(
      el.shadowRoot.querySelector('[data-id="zone"]').textContent
    ).toContain("Zone rouge");
    expect(el.shadowRoot.querySelectorAll(".step").length).toBe(6);
  });

  it("affiche la zone verte et la cascade", async () => {
    simuler.mockResolvedValue(RESULTAT_VERT);
    const el = monter();
    await flush();

    const barre = el.shadowRoot.querySelector('[data-id="barre"]');
    expect(barre.className).toContain("z-green");
    const pastilles = [...el.shadowRoot.querySelectorAll(".chip")].map(
      (c) => c.textContent
    );
    expect(pastilles).toContain("cascade 2 PAC");
    expect(pastilles).toContain("fM ×2");
    expect(pastilles).toContain("mitoyenneté non renseignée −5 %");
  });

  it("signale une maison construite après 1997", async () => {
    simuler.mockResolvedValue({
      ...RESULTAT_ROUGE,
      Statut__c: "Éligible · maison après 1997"
    });
    const el = monter();
    await flush();

    expect(el.shadowRoot.querySelector('[data-id="indice"]').textContent).toBe(
      "3,0"
    );
    expect(
      el.shadowRoot.querySelector('[data-id="message"]').textContent
    ).toContain("après 1997");
  });

  it("recalcule quand on choisit la mitoyenneté", async () => {
    simuler.mockResolvedValue(RESULTAT_ROUGE);
    const el = monter();
    await flush();

    const choix = el.shadowRoot.querySelector(
      'lightning-combobox[data-champ="Mitoyennete__c"]'
    );
    choix.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Entre medianeras/ Con dos medianeras" }
      })
    );
    await new Promise((resolve) => {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(resolve, 350);
    });

    expect(simuler).toHaveBeenCalledTimes(2);
    expect(simuler.mock.calls[1][0].simulation.Mitoyennete__c).toBe(
      "Entre medianeras/ Con dos medianeras"
    );
  });

  it("affiche le message quand il manque des infos", async () => {
    simuler.mockResolvedValue({
      Prix_Valorisation__c: 155,
      Statut__c: "En attente : renseigner la province et la surface"
    });
    const el = monter();
    await flush();

    expect(el.shadowRoot.querySelector('[data-id="indice"]').textContent).toBe(
      "—"
    );
    expect(
      el.shadowRoot.querySelector('[data-id="message"]').textContent
    ).toContain("renseigner la province");
  });

  it("recalcule quand on clique sur le bono social", async () => {
    simuler.mockResolvedValue(RESULTAT_ROUGE);
    const el = monter();
    await flush();

    const oui = el.shadowRoot.querySelector(
      'button[data-champ="Bono_Social__c"][data-valeur="true"]'
    );
    oui.click();
    await flush();

    expect(simuler).toHaveBeenCalledTimes(2);
    expect(simuler.mock.calls[1][0].simulation.Bono_Social__c).toBe(true);
    expect(oui.getAttribute("aria-pressed")).toBe("true");
  });

  it("affiche l'erreur renvoyée par le serveur", async () => {
    simuler.mockRejectedValue({ body: { message: "Accès refusé" } });
    const el = monter();
    await flush();

    expect(el.shadowRoot.querySelector('[data-id="erreur"]').textContent).toBe(
      "Accès refusé"
    );
  });

  it("enregistre une nouvelle simulation", async () => {
    simuler.mockResolvedValue(RESULTAT_ROUGE);
    createRecord.mockResolvedValue({ id: "a0P000000000001" });
    const el = monter();
    await flush();

    el.shadowRoot.querySelector('[data-id="enregistrer"]').click();
    await flush();

    expect(createRecord).toHaveBeenCalledTimes(1);
    const arg = createRecord.mock.calls[0][0];
    expect(arg.apiName).toBe("Simulation_RES060__c");
    expect(arg.fields.Type_Chaudiere__c).toBe("Gaz");
  });
});
