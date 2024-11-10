export interface ProductData {
  productId: string;
  type: 'SUBSCRIPTION' | 'NON_SUBSCRIPTION';
}

export const productDataMap: { [productId: string]: ProductData } = {
  '1m': {
    productId: '1m',
    type: 'SUBSCRIPTION',
  },
  '1y': {
    productId: '1y',
    type: 'SUBSCRIPTION',
  },
};
