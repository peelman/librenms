<!--
  - SettingMap.vue
  -
  - Component for simple key-value pair arrays (like ASN -> description)
  -
  - This program is free software: you can redistribute it and/or modify
  - it under the terms of the GNU General Public License as published by
  - the Free Software Foundation, either version 3 of the License, or
  - (at your option) any later version.
  -
  - This program is distributed in the hope that it will be useful,
  - but WITHOUT ANY WARRANTY; without even the implied warranty of
  - MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
  - GNU General Public License for more details.
  -
  - You should have received a copy of the GNU General Public License
  - along with this program.  If not, see <https://www.gnu.org/licenses/>.
  -
  - @package    LibreNMS
  - @link       https://www.librenms.org
  -->

<template>
    <div v-tooltip="disabled ? $t('settings.readonly') : false">
        <!-- Existing items -->
        <div v-for="(itemValue, itemKey) in localList" :key="itemKey" class="keyed-item">
            <div class="keyed-pair">
                <div class="keyed-key">
                    <input type="text"
                           :class="['form-control', keyError(itemKey) ? 'has-error-input' : '']"
                           :value="editingKeys[itemKey] !== undefined ? editingKeys[itemKey] : itemKey"
                           :readonly="disabled"
                           :placeholder="keyPlaceholder"
                           @input="onKeyInput(itemKey, $event.target.value)"
                           @blur="commitKey(itemKey, $event.target.value)"
                           @keyup.enter="commitKey(itemKey, $event.target.value)"
                    >
                </div>
                <div class="keyed-value">
                    <div class="input-group">
                        <input type="text"
                               class="form-control"
                               :value="itemValue"
                               :readonly="disabled"
                               :placeholder="valuePlaceholder"
                               @blur="updateValue(itemKey, $event.target.value)"
                               @keyup.enter="updateValue(itemKey, $event.target.value)"
                        >
                        <span class="input-group-btn">
                            <button v-if="!disabled" @click="removeItem(itemKey)" type="button" class="btn btn-danger"><i class="fa fa-minus-circle"></i></button>
                        </span>
                    </div>
                </div>
            </div>
            <div v-if="keyError(itemKey)" class="text-danger small keyed-error">{{ keyError(itemKey) }}</div>
        </div>
        <!-- New item row -->
        <div v-if="!disabled" class="keyed-item">
            <div class="keyed-pair">
                <div class="keyed-key">
                    <input type="text"
                           :class="['form-control', newKeyError ? 'has-error-input' : '']"
                           v-model="newItemKey"
                           :placeholder="keyPlaceholder"
                           @input="validateNewKey"
                    >
                </div>
                <div class="keyed-value">
                    <div class="input-group">
                        <input type="text"
                               class="form-control"
                               v-model="newItemValue"
                               :placeholder="valuePlaceholder"
                               @keyup.enter="addItem"
                        >
                        <span class="input-group-btn">
                            <button @click="addItem" type="button" class="btn btn-primary"><i class="fa fa-plus-circle"></i></button>
                        </span>
                    </div>
                </div>
            </div>
            <div v-if="newKeyError" class="text-danger small keyed-error">{{ newKeyError }}</div>
        </div>
    </div>
</template>

<script>
    import BaseSetting from "./BaseSetting.vue";
    import _ from "lodash";

    export default {
        name: "SettingMap",
        mixins: [BaseSetting],

        data() {
            return {
                localList: this.value ?? {},
                newItemKey: "",
                newItemValue: "",
                newKeyError: "",
                keyErrors: {},
                editingKeys: {}  // Track in-progress key edits separately
            }
        },
        created() {
            this.debouncedValidateExistingKey = _.debounce(this.validateExistingKey, 300);
            this.debouncedValidateNewKey = _.debounce(this.validateNewKeyRemote, 300);
        },
        computed: {
            keyPlaceholder() {
                return this.options?.keyPlaceholder || 'Key';
            },
            valuePlaceholder() {
                return this.options?.valuePlaceholder || 'Value';
            },
        },
        methods: {
            async requestKeyValidation(key, value) {
                try {
                    const response = await axios.post(route('settings.validate', this.name), {
                        scope: 'key',
                        key,
                        value,
                    });

                    return { valid: response.data.valid !== false, error: null };
                } catch (error) {
                    return {
                        valid: false,
                        error: error.response?.data?.message || 'Invalid key'
                    };
                }
            },
            async validateExistingKey(oldKey, newValue) {
                if (!newValue.trim()) return;

                if (Object.prototype.hasOwnProperty.call(this.localList, newValue) && newValue !== oldKey) {
                    this.$set(this.keyErrors, oldKey, this.$t('settings.validate.duplicate_key'));
                    return;
                }

                const result = await this.requestKeyValidation(newValue, this.localList[oldKey]);
                if (!result.valid) {
                    this.$set(this.keyErrors, oldKey, result.error);
                } else {
                    this.$delete(this.keyErrors, oldKey);
                }
            },
            async validateNewKeyRemote() {
                if (!this.newItemKey.trim()) {
                    this.newKeyError = '';
                    return;
                }

                if (Object.prototype.hasOwnProperty.call(this.localList, this.newItemKey)) {
                    this.newKeyError = this.$t('settings.validate.duplicate_key');
                    return;
                }

                const result = await this.requestKeyValidation(this.newItemKey, this.newItemValue);
                this.newKeyError = result.valid ? '' : result.error;
            },
            keyError(key) {
                return this.keyErrors[key] || '';
            },
            onKeyInput(oldKey, newValue) {
                // Track the editing value
                this.$set(this.editingKeys, oldKey, newValue);

                if (newValue.trim()) {
                    this.debouncedValidateExistingKey(oldKey, newValue);
                } else {
                    this.$delete(this.keyErrors, oldKey);
                }
            },
            commitKey(oldKey, newKey) {
                // Clean up editing state
                this.$delete(this.editingKeys, oldKey);

                if (this.disabled) return;
                if (oldKey === newKey) return;
                if (!newKey.trim()) return;

                if (Object.prototype.hasOwnProperty.call(this.localList, newKey)) {
                    this.$set(this.keyErrors, oldKey, this.$t('settings.validate.duplicate_key'));
                    return;
                }

                if (this.keyErrors[oldKey]) return;

                // Clear any error for this key
                this.$delete(this.keyErrors, oldKey);

                // Create new object with renamed key (preserving order as much as possible)
                const newList = {};
                for (const [k, v] of Object.entries(this.localList)) {
                    if (k === oldKey) {
                        newList[newKey] = v;
                    } else {
                        newList[k] = v;
                    }
                }
                this.localList = newList;
                this.$emit('input', this.localList);
            },
            validateNewKey() {
                this.debouncedValidateNewKey();
            },
            addItem() {
                if (this.disabled) return;
                if (!this.newItemKey.trim()) return;

                if (Object.prototype.hasOwnProperty.call(this.localList, this.newItemKey)) {
                    this.newKeyError = this.$t('settings.validate.duplicate_key');
                    return;
                }

                if (this.newKeyError) return;

                // Create a new object to ensure reactivity
                this.localList = {
                    ...this.localList,
                    [this.newItemKey]: this.newItemValue
                };
                this.$emit('input', this.localList);
                this.newItemKey = "";
                this.newItemValue = "";
                this.newKeyError = "";
            },
            removeItem(key) {
                if (this.disabled) return;

                // Create a new object without the removed key
                const { [key]: removed, ...rest } = this.localList;
                this.localList = rest;

                // Clean up error tracking
                const { [key]: removedError, ...restErrors } = this.keyErrors;
                this.keyErrors = restErrors;

                // Clean up editing state
                const { [key]: removedEdit, ...restEdits } = this.editingKeys;
                this.editingKeys = restEdits;

                this.$emit('input', this.localList);
            },
            updateValue(key, value) {
                if (this.disabled || this.localList[key] === value) return;

                this.localList = {
                    ...this.localList,
                    [key]: value
                };
                this.$emit('input', this.localList);
            }
        },
        watch: {
            value(updated) {
                // careful to avoid loops with this
                this.localList = updated ?? {};
            }
        }
    }
</script>

<style scoped>
    .keyed-item {
        margin-bottom: 10px;
        padding-bottom: 10px;
        border-bottom: 1px solid #eee;
    }

    .keyed-item:last-child {
        border-bottom: none;
        margin-bottom: 0;
        padding-bottom: 0;
    }

    .keyed-pair {
        display: flex;
        gap: 10px;
    }

    .keyed-key {
        flex: 0 0 40%;
    }

    .keyed-value {
        flex: 1;
    }

    .keyed-key .form-control,
    .keyed-value .form-control {
        padding-right: 12px;
    }

    .keyed-error {
        margin-top: 2px;
    }

    .has-error-input {
        border-color: #a94442 !important;
        background-color: #f2dede !important;
    }

    /* Stack on small screens */
    @media (max-width: 991px) {
        .keyed-pair {
            flex-direction: column;
            gap: 5px;
        }

        .keyed-key {
            flex: 1;
        }
    }
</style>
