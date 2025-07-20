import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
    name: "User registration with valid parameters succeeds",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('plasma-milestone-tracker', 'register-user', 
                [types.ascii('Alice Johnson'), types.uint(2)], 
                deployer.address)
        ]);

        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Milestone creation requires valid plasma network",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const block = chain.mineBlock([
            Tx.contractCall('plasma-milestone-tracker', 'create-milestone', 
                [
                    types.ascii('Neural Network Basics'),
                    types.ascii('Understand fundamental neural network concepts'),
                    types.ascii('Machine Learning'),
                    types.uint(2),
                    types.uint(1),
                    types.none()
                ], 
                deployer.address)
        ]);

        block.receipts[0].result.expectErr();
    }
});