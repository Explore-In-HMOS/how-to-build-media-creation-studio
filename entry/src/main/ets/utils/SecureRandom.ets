import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';

export function secureRandomNumber(): number {
  try {
    const rand = cryptoFramework.createRandom();
    const randData = rand.generateRandomSync(8);
    const bytes = randData.data;
    let v = BigInt(0);
    for (let i = 0; i < 8; i++) {
      v = (v << BigInt(8)) | BigInt(bytes[i]);
    }
    return Number(v >> BigInt(11)) / Number(BigInt(1) << BigInt(53));
  } catch (err) {
    const e = err as BusinessError;
    console.warn(`SecureRandom failed: ${e.code} ${e.message}`);
    return Number((BigInt(Date.now()) * BigInt(2654435761)) & BigInt(0xffffffff)) / 0x100000000;
  }
}

export function secureRandomId(): string {
  const a = Math.floor(secureRandomNumber() * 0xffffffff).toString(16).padStart(8, '0');
  const b = Math.floor(secureRandomNumber() * 0xffffffff).toString(16).padStart(8, '0');
  return `${a}${b}`;
}
