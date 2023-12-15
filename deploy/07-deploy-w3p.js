const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("----------------------------------------------------")
    const arguments = ["0x5C6a6E50121142ad816a3A6Cc1A3e65A14f0E42d"]
    const W3P = await deploy("testContract", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 6,
    })
    console.log("address is : ", W3P.address)

    // Verify the deployment
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify("0x16CC29231800E0468e5c929aB494d0eF1D461D08", arguments)
    }
}

module.exports.tags = ["all", "w3p", "main"]
