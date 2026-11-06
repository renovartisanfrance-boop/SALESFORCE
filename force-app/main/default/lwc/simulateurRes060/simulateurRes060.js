import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getObjectInfo, getPicklistValues } from "lightning/uiObjectInfoApi";
import { getRecord, createRecord, updateRecord } from "lightning/uiRecordApi";
import simuler from "@salesforce/apex/SimulationRES060Controller.simuler";
import SIMULATION from "@salesforce/schema/Simulation_RES060__c";
import PROVINCE from "@salesforce/schema/Simulation_RES060__c.Province__c";
import CODE_POSTAL from "@salesforce/schema/Simulation_RES060__c.Code_Postal__c";
import SURFACE from "@salesforce/schema/Simulation_RES060__c.Surface__c";
import ANNEE_MAISON from "@salesforce/schema/Simulation_RES060__c.Annee_Maison__c";
import TYPE_CHAUDIERE from "@salesforce/schema/Simulation_RES060__c.Type_Chaudiere__c";
import ANNEE_CHAUDIERE from "@salesforce/schema/Simulation_RES060__c.Annee_Chaudiere__c";
import CONDENSATION from "@salesforce/schema/Simulation_RES060__c.Condensation__c";
import BONO from "@salesforce/schema/Simulation_RES060__c.Bono_Social__c";
import PRIX from "@salesforce/schema/Simulation_RES060__c.Prix_Valorisation__c";

const CHAMPS = [
  PROVINCE,
  CODE_POSTAL,
  SURFACE,
  ANNEE_MAISON,
  TYPE_CHAUDIERE,
  ANNEE_CHAUDIERE,
  CONDENSATION,
  BONO,
  PRIX
];
const CHAMPS_NOMBRE = new Set([
  "Surface__c",
  "Annee_Maison__c",
  "Annee_Chaudiere__c",
  "Prix_Valorisation__c"
]);
const DELAI_CALCUL_MS = 300;
const TRANCHES = [
  "≤1940",
  "1941-1960",
  "1961-1980",
  "1981-2007",
  "2008-2012",
  "2013-2019",
  ">2019"
];

const nombre = (n, decimales = 0) =>
  new Intl.NumberFormat("fr-FR", {
    minimumFractionDigits: decimales,
    maximumFractionDigits: decimales
  }).format(n);
const euros = (n) => nombre(Math.round(n)) + " €";

function tranche(annee) {
  if (annee === null || annee === undefined || annee === "") {
    return "≤1940 (défaut, max)";
  }
  const bornes = [1940, 1960, 1980, 2007, 2012, 2019];
  const i = bornes.findIndex((b) => annee <= b);
  return TRANCHES[i === -1 ? 6 : i];
}

function messageErreur(e) {
  return e?.body?.message || e?.message || "Erreur inconnue";
}

export default class SimulateurRes060 extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  saisie = {
    Province__c: null,
    Code_Postal__c: null,
    Surface__c: null,
    Annee_Maison__c: null,
    Type_Chaudiere__c: "Gaz",
    Annee_Chaudiere__c: 2005,
    Condensation__c: false,
    Bono_Social__c: false,
    Prix_Valorisation__c: null
  };
  resultat;
  erreur;
  enregistrement = false;
  provinces = [];
  typesChaudiere = [];
  minuterie;

  @wire(getObjectInfo, { objectApiName: SIMULATION })
  objectInfo;

  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: PROVINCE
  })
  wiredProvinces({ data }) {
    if (data) {
      this.provinces = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    }
  }

  @wire(getPicklistValues, {
    recordTypeId: "$objectInfo.data.defaultRecordTypeId",
    fieldApiName: TYPE_CHAUDIERE
  })
  wiredTypes({ data }) {
    if (data) {
      this.typesChaudiere = data.values.map((v) => ({
        label: v.label,
        value: v.value
      }));
    }
  }

  @wire(getRecord, { recordId: "$recordId", fields: CHAMPS })
  wiredRecord({ data, error }) {
    if (data) {
      const lu = {};
      CHAMPS.forEach((f) => {
        lu[f.fieldApiName] = data.fields[f.fieldApiName]?.value ?? null;
      });
      this.saisie = lu;
      this.calculer();
    } else if (error) {
      this.erreur = messageErreur(error);
    }
  }

  connectedCallback() {
    if (!this.recordId) {
      this.calculer();
    }
  }

  disconnectedCallback() {
    clearTimeout(this.minuterie);
  }

  // ---------- Saisie ----------

  handleChange(event) {
    const champ = event.target.dataset.champ;
    let valeur = event.detail?.value ?? event.target.value;
    if (valeur === "" || valeur === undefined) {
      valeur = null;
    } else if (CHAMPS_NOMBRE.has(champ)) {
      valeur = Number(String(valeur).replace(",", "."));
      if (Number.isNaN(valeur)) {
        valeur = null;
      }
    }
    this.saisie = { ...this.saisie, [champ]: valeur };
    this.planifierCalcul();
  }

  handleSegment(event) {
    const { champ, valeur } = event.currentTarget.dataset;
    this.saisie = { ...this.saisie, [champ]: valeur === "true" };
    this.calculer();
  }

  planifierCalcul() {
    clearTimeout(this.minuterie);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.minuterie = setTimeout(() => this.calculer(), DELAI_CALCUL_MS);
  }

  async calculer() {
    try {
      this.resultat = await simuler({
        simulation: { sobjectType: "Simulation_RES060__c", ...this.saisie }
      });
      this.erreur = undefined;
    } catch (e) {
      this.erreur = messageErreur(e);
    }
  }

  async handleEnregistrer() {
    this.enregistrement = true;
    try {
      const fields = { ...this.saisie };
      if (this.recordId) {
        await updateRecord({ fields: { Id: this.recordId, ...fields } });
        this.toast("Simulation mise à jour", "success");
      } else {
        const cree = await createRecord({
          apiName: SIMULATION.objectApiName,
          fields
        });
        this.toast("Simulation enregistrée", "success");
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: {
            recordId: cree.id,
            objectApiName: SIMULATION.objectApiName,
            actionName: "view"
          }
        });
      }
    } catch (e) {
      this.toast(messageErreur(e), "error");
    } finally {
      this.enregistrement = false;
    }
  }

  toast(message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: variant === "error" ? "Erreur" : message,
        message: variant === "error" ? message : "",
        variant
      })
    );
  }

  // ---------- Affichage ----------

  get libelleBouton() {
    return this.recordId
      ? "Enregistrer les modifications"
      : "Enregistrer la simulation";
  }

  get condNon() {
    return String(!this.saisie.Condensation__c);
  }
  get condOui() {
    return String(Boolean(this.saisie.Condensation__c));
  }
  get bonoNon() {
    return String(!this.saisie.Bono_Social__c);
  }
  get bonoOui() {
    return String(Boolean(this.saisie.Bono_Social__c));
  }

  get prixPlaceholder() {
    const p = this.resultat?.Prix_Valorisation__c;
    return p ? "Par défaut : " + nombre(p) : "Ex : 155";
  }

  get calcule() {
    return (
      this.resultat?.Indice__c !== undefined &&
      this.resultat?.Indice__c !== null
    );
  }

  get verte() {
    return this.calcule && this.resultat.Zone__c?.startsWith("Zone verte");
  }

  get classeBarre() {
    if (!this.calcule) {
      return "benefbar";
    }
    return this.verte ? "benefbar z-green" : "benefbar z-red";
  }

  get indiceTexte() {
    return this.calcule ? nombre(this.resultat.Indice__c, 1) : "—";
  }

  get statutTexte() {
    const s = this.resultat?.Statut__c || "";
    if (s.startsWith("Éligible")) {
      return "Éligible";
    }
    if (s.startsWith("Non éligible")) {
      return "Non éligible";
    }
    if (s.startsWith("Donnée manquante")) {
      return "Donnée manquante";
    }
    return "En attente";
  }

  get classeStatut() {
    if (this.statutTexte === "Éligible") {
      return "status ok";
    }
    return this.statutTexte === "En attente" ? "status" : "status ko";
  }

  get message() {
    const s = this.resultat?.Statut__c || "";
    return s && !s.startsWith("Éligible") ? s : null;
  }

  get classeMessage() {
    return this.statutTexte === "Non éligible" ? "badbox" : "warnbox";
  }

  get provinceDeduite() {
    return !this.saisie.Province__c && this.resultat?.Province__c
      ? this.resultat.Province__c
      : null;
  }

  get pastilles() {
    if (!this.calcule || this.resultat.DCAL__c == null) {
      return [];
    }
    const r = this.resultat;
    const liste = [
      "D_CAL " + nombre(r.DCAL__c, 1) + " kWh/m²",
      "η = " + nombre(r.Rendement__c, 2),
      "fC ×2",
      nombre(r.Prix_Valorisation__c) + " €/MWh"
    ];
    if (this.saisie.Bono_Social__c) {
      liste.push("vuln ×1,5");
    }
    if (r.Statut__c?.includes("cascade")) {
      liste.push("cascade 2 PAC");
    }
    return liste.map((label, i) => ({ id: i, label }));
  }

  get resume() {
    if (!this.calcule || this.resultat.DCAL__c == null) {
      return null;
    }
    const r = this.resultat;
    return {
      prime: euros(r.Prime__c),
      cout: euros(r.Cout_Pack__c),
      benefice: euros(r.Benefice__c)
    };
  }

  get etapes() {
    if (!this.calcule || this.resultat.DCAL__c == null) {
      return [];
    }
    const r = this.resultat;
    const s = this.saisie;
    const cascade = r.Statut__c?.includes("cascade");
    const aes = nombre(r.AES_MWh__c, 2);
    return [
      {
        n: "1",
        titre: "D_CAL — demande de chauffage",
        calcul:
          "Province " +
          r.Province__c +
          ", millésime " +
          tranche(s.Annee_Maison__c) +
          " → " +
          nombre(r.DCAL__c, 1) +
          " kWh/m²·an"
      },
      {
        n: "2",
        titre: "Rendement chaudière (η)",
        calcul:
          (s.Type_Chaudiere__c || "") +
          (s.Annee_Chaudiere__c ? " " + s.Annee_Chaudiere__c : "") +
          (s.Condensation__c ? " condensation" : "") +
          " → η = " +
          nombre(r.Rendement__c, 2)
      },
      {
        n: "3",
        titre: "AES — épargne annuelle",
        calcul: "D_CAL × S × (1/η − 1/SCOP) = " + aes + " MWh/an"
      },
      {
        n: "4",
        titre: "Prime",
        calcul:
          "AES " +
          aes +
          " MWh × fC 2" +
          (s.Bono_Social__c ? " × 1,5" : "") +
          " × " +
          nombre(r.Prix_Valorisation__c) +
          " €/MWh = " +
          euros(r.Prime__c)
      },
      {
        n: "5",
        titre: "Coût pack",
        calcul:
          (cascade ? "Cascade 2 PAC (>220 m²)" : "1 PAC (≤220 m²)") +
          " = " +
          euros(r.Cout_Pack__c)
      },
      {
        n: "6",
        titre: "Bénéfice",
        calcul: "Prime − coût pack = " + euros(r.Benefice__c)
      }
    ];
  }
}
