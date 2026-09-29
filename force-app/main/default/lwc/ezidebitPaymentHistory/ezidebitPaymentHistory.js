import { LightningElement, api, wire } from 'lwc';
import getHistory from '@salesforce/apex/EzidebitPaymentHistoryController.getHistory';

// Every payment and every failed Ezidebit debit on the agreement, newest first.
const COLUMNS = [
    { label: 'Date', fieldName: 'eventDate', type: 'date-local', initialWidth: 110,
      typeAttributes: { day: '2-digit', month: 'short', year: 'numeric' } },
    { label: 'Result', fieldName: 'result', initialWidth: 110, cellAttributes: { class: { fieldName: 'resultClass' } } },
    { label: 'Type', fieldName: 'type', initialWidth: 150 },
    { label: 'Amount', fieldName: 'amount', type: 'currency', initialWidth: 110 },
    { label: 'Ezidebit fee', fieldName: 'ezidebitFee', type: 'currency', initialWidth: 115 },
    { label: 'R4K fee', fieldName: 'r4kFee', type: 'currency', initialWidth: 100 },
    { label: 'Detail', fieldName: 'detail', wrapText: true },
    { label: 'Record', fieldName: 'link', type: 'url', initialWidth: 130,
      typeAttributes: { label: { fieldName: 'name' }, target: '_self' } }
];

const RESULT_CLASS = {
    Paid: 'slds-text-color_success',
    Failed: 'slds-text-color_error',
    'Taken back': 'slds-text-color_error'
};

export default class EzidebitPaymentHistory extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    rows = [];
    summary;
    error;
    loaded = false;

    @wire(getHistory, { opportunityId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.rows = data.rows.map((r) => ({
                ...r,
                link: '/' + r.recordId,
                resultClass: RESULT_CLASS[r.result] || ''
            }));
            this.summary = data;
            this.columns = data.showEzidebitFees ? COLUMNS : COLUMNS.filter((c) => c.fieldName !== 'ezidebitFee');
            this.error = undefined;
            this.loaded = true;
        } else if (error) {
            this.error = error.body && error.body.message ? error.body.message : 'The payment history could not be loaded.';
            this.loaded = true;
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get summaryLine() {
        if (!this.summary) {
            return '';
        }
        const s = this.summary;
        const money = (n) => new Intl.NumberFormat('en-AU', { style: 'currency', currency: 'AUD' }).format(n || 0);
        const ezidebit = s.showEzidebitFees ? ` · Ezidebit fees ${money(s.ezidebitFees)}` : '';
        return `${s.paidCount} paid (${money(s.paidAmount)}) · ${s.failedCount} failed · ${s.openInstalments} missed instalment${s.openInstalments === 1 ? '' : 's'} open${ezidebit} · R4K fees ${money(s.r4kFees)}`;
    }
}